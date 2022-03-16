//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./ERC721Token.sol";
import "./ERC20.sol";

contract Marketplace is AccessControl {
    enum SellItemStatus {
        OWNERED,
        IN_SELL
    }

    enum AuctionStatus {
        STARTED,
        FINISHED
    }

    struct SellOrderItem {
        address seller;
        uint256 price;
        SellItemStatus status;
    }

    struct AuctionItem {
        uint256 bidderCounter;
        address auctionCreator;
        uint256 higherBid;
        address higherBidder;
        uint256 startTimestamp;
        AuctionStatus status;
    }

    address public ERC721_TOKEN;
    address public ERC20_TOKEN;
    using Counters for Counters.Counter;
    Counters.Counter private _ids;
    mapping(uint256 => SellOrderItem) public sellOrderList;
    mapping(uint256 => AuctionItem) public auctionOrderList;
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

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setTokensAddresses(address erc721Addr, address erc20Addr) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "You cannot set address of tokens"
        );
        ERC721_TOKEN = erc721Addr;
        ERC20_TOKEN = erc20Addr;
    }

    function createItem(string memory metadata, address owner) public {
        _ids.increment();
        ERC721Token(ERC721_TOKEN).mint(_ids.current(), owner, metadata);
    }

    function listItem(uint256 tokenId, uint256 price) public {
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        sellOrderList[tokenId] = SellOrderItem({
            seller: msg.sender,
            price: price,
            status: SellItemStatus.IN_SELL
        });

        emit ItemListed(msg.sender, price);
    }

    function buyItem(uint256 tokenId) public {
        require(
            sellOrderList[tokenId].status == SellItemStatus.IN_SELL,
            "Cannot buy non sold item"
        );
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
        sellOrderList[tokenId].status = SellItemStatus.OWNERED;

        emit ItemSold(msg.sender, sellOrderList[tokenId].price);
    }

    function cancel(uint256 tokenId) public {
        require(sellOrderList[tokenId].seller == msg.sender, "Not seller");
        sellOrderList[tokenId].status = SellItemStatus.OWNERED;
        emit SaleCanceled(msg.sender, tokenId);
    }

    function listItemOnAuction(uint256 tokenId, uint256 minPrice) public {
        require(
            auctionOrderList[tokenId].startTimestamp == 0,
            "Auction with this token is alredy started"
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
            auctionOrderList[tokenId].startTimestamp != 0 &&
                block.timestamp <=
                auctionOrderList[tokenId].startTimestamp + AUCTION_DURING,
            "Nonexistent auction"
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

    function finishAution(uint256 tokenId) public {
        require(
            auctionOrderList[tokenId].startTimestamp != 0,
            "Nonexistent auction"
        );
        require(
            block.timestamp >=
                auctionOrderList[tokenId].startTimestamp + AUCTION_DURING,
            "Auction is not over"
        );

        if (auctionOrderList[tokenId].bidderCounter > 2) {
            ERC721Token(ERC721_TOKEN).safeTransferFrom(
                address(this),
                auctionOrderList[tokenId].higherBidder,
                tokenId
            );
            ERC20(ERC20_TOKEN).transfer(
                auctionOrderList[tokenId].auctionCreator,
                auctionOrderList[tokenId].higherBid
            );
        } else {
            ERC721Token(ERC721_TOKEN).safeTransferFrom(
                address(this),
                auctionOrderList[tokenId].auctionCreator,
                tokenId
            );

            ERC20(ERC20_TOKEN).transfer(
                auctionOrderList[tokenId].higherBidder,
                auctionOrderList[tokenId].higherBid
            );
        }

        emit AuctionFinished(
            msg.sender,
            auctionOrderList[tokenId].auctionCreator,
            auctionOrderList[tokenId].higherBidder,
            tokenId
        );

        delete auctionOrderList[tokenId];
    }

    function cancelAuction() public {
        /**
            отменить аукцион
         */
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
