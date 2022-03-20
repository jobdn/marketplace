//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERC721Token.sol";
import "./ERC20.sol";

contract Marketplace is AccessControl, ReentrancyGuard {
    enum OrderStatus {
        UNDEFINED,
        OWNED,
        IN_SELL,
        AUCTION_IS_STARTED,
        AUCTION_IS_FINISHED,
        AUCTION_IS_CANCELED
    }

    struct Order {
        uint256 bidderCounter;
        uint256 currentPrice;
        uint256 auctionStartTime;
        address creator;
        address higherBidder;
        OrderStatus status;
    }

    address public ERC721_TOKEN;
    address public ERC20_TOKEN;
    using Counters for Counters.Counter;
    Counters.Counter private _ids;
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
    function createItem(string memory metadata, address owner)
        public
        nonReentrant
    {
        _ids.increment();
        ERC721Token(ERC721_TOKEN).mint(_ids.current(), owner, metadata);
    }

    /**
        @notice Offers for sale token

        @dev Owner of token needs to approve the marketplace to transfer token with tokenId.
            When this function is called, marketplace becomes the owner of the token with tokenId. 
            Therefore it's impossible to offer the same token for sale 

            Order is created for every token with IN_SELL status in 'orders'.
            If order has the 'IN_SELL' status it means that token is put up for sale.

        @param tokenId Token's id
        @param price Selling price
     */
    function listItem(uint256 tokenId, uint256 price) public nonReentrant {
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        orders[tokenId] = Order({
            bidderCounter: 0,
            currentPrice: price,
            auctionStartTime: block.timestamp,
            creator: msg.sender,
            higherBidder: msg.sender,
            status: OrderStatus.IN_SELL
        });

        emit ItemListed(msg.sender, price);
    }

    /**
        @notice Buyes token which is put up for sale
        @dev We need check token is put up for sale

        @param tokenId Token's id which is put up for sale
     */
    function buyItem(uint256 tokenId) public nonReentrant {
        require(orders[tokenId].status == OrderStatus.IN_SELL, "Non sold item");
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        ERC20(ERC20_TOKEN).transferFrom(
            msg.sender,
            orders[tokenId].creator,
            orders[tokenId].currentPrice
        );

        orders[tokenId].creator = msg.sender;
        orders[tokenId].status = OrderStatus.OWNED;

        emit ItemSold(msg.sender, orders[tokenId].currentPrice);
    }

    function cancel(uint256 tokenId) public nonReentrant {
        require(msg.sender == orders[tokenId].creator, "Not creator");
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            address(this),
            orders[tokenId].creator,
            tokenId
        );
        orders[tokenId].status = OrderStatus.OWNED;
        emit SaleCanceled(msg.sender, tokenId);
    }

    function listItemOnAuction(uint256 tokenId, uint256 minPrice)
        public
        nonReentrant
    {
        require(
            orders[tokenId].status != OrderStatus.AUCTION_IS_STARTED,
            "Auction is already started"
        );
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        orders[tokenId] = Order({
            bidderCounter: 0,
            creator: msg.sender,
            currentPrice: minPrice,
            higherBidder: address(0),
            auctionStartTime: block.timestamp,
            status: OrderStatus.AUCTION_IS_STARTED
        });

        emit AuctionStarted(msg.sender, tokenId, minPrice);
    }

    function makeBid(uint256 tokenId, uint256 price) public nonReentrant {
        require(
            orders[tokenId].status == OrderStatus.AUCTION_IS_STARTED,
            "Auction is not started"
        );
        require(
            block.timestamp <=
                orders[tokenId].auctionStartTime + AUCTION_DURING,
            "Auction is over"
        );
        require(price > orders[tokenId].currentPrice, "Not enough bid");

        address prevHigherBidder = orders[tokenId].higherBidder;
        uint256 prevHigherBid = orders[tokenId].currentPrice;
        ERC20(ERC20_TOKEN).transferFrom(msg.sender, address(this), price);
        orders[tokenId].currentPrice = price;
        orders[tokenId].higherBidder = msg.sender;

        if (orders[tokenId].bidderCounter > 0) {
            ERC20(ERC20_TOKEN).transfer(prevHigherBidder, prevHigherBid);
        }

        orders[tokenId].bidderCounter++;

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

    function finishAution(uint256 tokenId) public nonReentrant {
        require(
            block.timestamp >=
                orders[tokenId].auctionStartTime + AUCTION_DURING,
            "Auction is not over"
        );

        if (orders[tokenId].bidderCounter > 2) {
            address auctionWinner = orders[tokenId].higherBidder;
            uint256 erc721TokenToWinner = tokenId;
            uint256 erc20ToActionCreator = orders[tokenId].currentPrice;

            sendTokensAfterFinishAuction(
                auctionWinner,
                erc721TokenToWinner,
                orders[tokenId].creator,
                erc20ToActionCreator
            );
        } else if (orders[tokenId].bidderCounter == 0) {
            ERC721Token(ERC721_TOKEN).safeTransferFrom(
                address(this),
                orders[tokenId].creator,
                tokenId
            );
        } else {
            address lastBidder = orders[tokenId].higherBidder;
            uint256 erc20TokenOfLastBidder = orders[tokenId].currentPrice;

            sendTokensAfterFinishAuction(
                orders[tokenId].creator,
                tokenId,
                lastBidder,
                erc20TokenOfLastBidder
            );
        }

        orders[tokenId].status = OrderStatus.AUCTION_IS_FINISHED;

        emit AuctionFinished(
            msg.sender,
            orders[tokenId].creator,
            orders[tokenId].higherBidder,
            tokenId
        );
    }

    function cancelAuction(uint256 tokenId) public {
        require(msg.sender == orders[tokenId].creator, "Not auction owner");

        require(
            orders[tokenId].status != OrderStatus.AUCTION_IS_FINISHED,
            "Auction is over"
        );

        if (orders[tokenId].bidderCounter > 0) {
            address lastBidder = orders[tokenId].higherBidder;
            uint256 erc20TokenOfLastBidder = orders[tokenId].currentPrice;

            sendTokensAfterFinishAuction(
                orders[tokenId].creator,
                tokenId,
                lastBidder,
                erc20TokenOfLastBidder
            );
        }

        orders[tokenId].status = OrderStatus.AUCTION_IS_CANCELED;
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
