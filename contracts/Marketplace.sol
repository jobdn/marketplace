//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERC721Token.sol";
import "./ERC20.sol";

/** @title  */
contract Marketplace is AccessControl {
    // enum SellItemStatus {
    //     OWNED,
    //     IN_SELL
    // }

    // enum AuctionStatus {
    //     IS_NOT_ON_AUCTION,
    //     STARTED,
    //     FINISHED,
    //     CANCELED
    // }

    // struct SellOrderItem {
    //     uint256 price; // price
    //     address seller; // creator
    //     SellItemStatus status; // status
    // }

    // struct AuctionItem {
    //     uint256 bidderCounter;
    //     uint256 higherBid;
    //     uint256 startTimestamp;
    //     address auctionCreator;
    //     address higherBidder;
    //     AuctionStatus status;
    // }

    enum OrderStatus {
        UNDEFINED,
        OWNED,
        IN_SELL,
        STARTED,
        FINISHED,
        CANCELED
    }

    struct Order {
        uint256 bidderCounter;
        uint256 currentPrice; // price
        uint256 auctionStartTime;
        address creator; // creator
        address higherBidder;
        AuctionStatus status; // Status
    }

    address public ERC721_TOKEN;
    address public ERC20_TOKEN;
    using Counters for Counters.Counter;
    Counters.Counter private _ids;
    // mapping(uint256 => SellOrderItem) public sellOrderList;
    // mapping(uint256 => AuctionItem) public auctionOrderList;
    mapping(uint256 => Order) public orders;
    uint256 private constant AUCTION_DURING = 3 days;

    event ItemListed(address indexed seller, uint256 price);
    event ItemSold(address indexed buyer, uint256 price);
    event SaleCanceled(address indexed closer, uint256 tokenId);
    event AuctionStarted(
        address indexed auctioneer,
        uint256 tokenId,
        uint256 minPrice
    );
    event BidMaked(address indexed bidder, uint256 tokenId, uint256 price);
    event AuctionFinished(
        address indexed finisher,
        address indexed creator,
        address indexed highBidder,
        uint256 tokenId
    );
    event AuctionClosed(
        address indexed closer,
        uint256 tokenId,
        uint256 closeTime
    );

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
        @dev Sets tokens addressess
        @param erc721Addr Address of ERC721 token
        @param erc20Addr Address of ERC20 token
     */
    function setTokensAddresses(address erc721Addr, address erc20Addr) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "You cannot set address of tokens"
        );
        ERC721_TOKEN = erc721Addr;
        ERC20_TOKEN = erc20Addr;
    }

    /**
        @notice Creates ERC721 token for owner
        @dev Token is stored on the owner's wallet after creating a token 
        @param metadata Metadata of ERC721 token
        @param owner Owner of creating token
     */
    function createItem(string memory metadata, address owner) public {
        _ids.increment();
        ERC721Token(ERC721_TOKEN).mint(_ids.current(), owner, metadata);
    }

    /**
        @notice Offers for sale token

        @dev Owner of token needs to approve the marketplace to transfer token with tokenId.
            When this function is called, marketplace becomes the owner of the token with tokenId. 
            Therefore it's impossible to offer the same token for sale 

            Order is created for every token with IN_SELL status in 'sellOrderList'.
            If order has the 'IN_SELL' status it means that token is put up for sale.

        @param tokenId Token's id
        @param price Selling price
     */
    function listItem(uint256 tokenId, uint256 price) public {
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        sellOrderList[tokenId] = Order({
            creator: msg.sender,
            currentPrice: price,
            status: OrderStatus.IN_SELL
        });

        emit ItemListed(msg.sender, price);
    }

    /**
        @notice Buyes token which is put up for sale
        @dev We need check token is put up for sale

        @param tokenId Token's id which is put up for sale
     */
    function buyItem(uint256 tokenId) public {
        require(orders[tokenId].status == OrderStatus.IN_SELL, "Non sold item");
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        ERC20(ERC20_TOKEN).transferFrom(
            msg.sender,
            sellOrderList[tokenId].seller,
            sellOrderList[tokenId].price
        );

        sellOrderList[tokenId].seller = msg.sender;
        sellOrderList[tokenId].status = SellItemStatus.OWNED;

        emit ItemSold(msg.sender, sellOrderList[tokenId].price);
    }

    function cancel(uint256 tokenId) public {
        require(msg.sender == sellOrderList[tokenId].seller, "Not seller");
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            address(this),
            sellOrderList[tokenId].seller,
            tokenId
        );
        sellOrderList[tokenId].status = SellItemStatus.OWNED;
        emit SaleCanceled(msg.sender, tokenId);
    }

    function listItemOnAuction(uint256 tokenId, uint256 minPrice) public {
        require(
            auctionOrderList[tokenId].status != AuctionStatus.STARTED,
            "Auction is already started"
        );
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        auctionOrderList[tokenId] = AuctionItem({
            bidderCounter: 0,
            auctionCreator: msg.sender,
            higherBid: minPrice,
            higherBidder: address(0),
            startTimestamp: block.timestamp,
            status: AuctionStatus.STARTED
        });

        emit AuctionStarted(msg.sender, tokenId, minPrice);
    }

    function makeBid(uint256 tokenId, uint256 price) public {
        require(
            auctionOrderList[tokenId].status == AuctionStatus.STARTED,
            "Auction is not started"
        );
        require(
            block.timestamp <=
                auctionOrderList[tokenId].startTimestamp + AUCTION_DURING,
            "Auction is over"
        );
        require(price > auctionOrderList[tokenId].higherBid, "Not enough bid");

        address preHigherBidder = auctionOrderList[tokenId].higherBidder;
        uint256 preHigherBid = auctionOrderList[tokenId].higherBid;
        ERC20(ERC20_TOKEN).transferFrom(msg.sender, address(this), price);
        auctionOrderList[tokenId].higherBid = price;
        auctionOrderList[tokenId].higherBidder = msg.sender;

        if (auctionOrderList[tokenId].bidderCounter > 0) {
            ERC20(ERC20_TOKEN).transfer(preHigherBidder, preHigherBid);
        }

        auctionOrderList[tokenId].bidderCounter++;

        emit BidMaked(msg.sender, tokenId, price);
    }

    /**
        @notice Sends ERC721 and ERC20 tokens to the addresses.
        @dev This function is usualy called after finishing or closing auction.  
        @param erc721Receiver Address that receives ERC721 token.
        @param erc721TokenId Token id which is set to auction.
        @param erc721Receiver ERC20 tokens receiver.
        @param erc20TokenAmount Amount of ERC20 tokens.
     */
    function sendTokensAfterFinishAuction(
        address erc721Receiver,
        uint256 erc721TokenId,
        address erc20Receiver,
        uint256 erc20TokenAmount
    ) internal {
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            address(this),
            erc721Receiver,
            erc721TokenId
        );
        ERC20(ERC20_TOKEN).transfer(erc20Receiver, erc20TokenAmount);
    }

    function finishAution(uint256 tokenId) public {
        require(
            block.timestamp >=
                auctionOrderList[tokenId].startTimestamp + AUCTION_DURING,
            "Auction is not over"
        );

        if (auctionOrderList[tokenId].bidderCounter > 2) {
            address auctionWinner = auctionOrderList[tokenId].higherBidder;
            uint256 erc721TokenToWinner = tokenId;
            uint256 erc20ToActionCreator = auctionOrderList[tokenId].higherBid;

            sendTokensAfterFinishAuction(
                auctionWinner,
                erc721TokenToWinner,
                auctionOrderList[tokenId].auctionCreator,
                erc20ToActionCreator
            );
        } else if (auctionOrderList[tokenId].bidderCounter == 0) {
            ERC721Token(ERC721_TOKEN).safeTransferFrom(
                address(this),
                auctionOrderList[tokenId].auctionCreator,
                tokenId
            );
        } else {
            address lastBidder = auctionOrderList[tokenId].higherBidder;
            uint256 erc20TokenOfLastBidder = auctionOrderList[tokenId]
                .higherBid;

            sendTokensAfterFinishAuction(
                auctionOrderList[tokenId].auctionCreator,
                tokenId,
                lastBidder,
                erc20TokenOfLastBidder
            );
        }

        auctionOrderList[tokenId].status = AuctionStatus.FINISHED;

        emit AuctionFinished(
            msg.sender,
            auctionOrderList[tokenId].auctionCreator,
            auctionOrderList[tokenId].higherBidder,
            tokenId
        );
    }

    function cancelAuction(uint256 tokenId) public {
        require(
            msg.sender == auctionOrderList[tokenId].auctionCreator,
            "Not auction owner"
        );

        require(
            auctionOrderList[tokenId].status != AuctionStatus.FINISHED,
            "Auction is over"
        );

        if (auctionOrderList[tokenId].bidderCounter > 0) {
            address lastBidder = auctionOrderList[tokenId].higherBidder;
            uint256 erc20TokenOfLastBidder = auctionOrderList[tokenId]
                .higherBid;

            sendTokensAfterFinishAuction(
                auctionOrderList[tokenId].auctionCreator,
                tokenId,
                lastBidder,
                erc20TokenOfLastBidder
            );
        }

        auctionOrderList[tokenId].status = AuctionStatus.CANCELED;
        emit AuctionClosed(msg.sender, tokenId, block.timestamp);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}
