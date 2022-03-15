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

    struct SellOrderItem {
        address seller;
        uint256 price;
        SellItemStatus status;
    }

    address public ERC721_TOKEN;
    address public ERC20_TOKEN;
    using Counters for Counters.Counter;
    Counters.Counter private _ids;
    mapping(uint256 => SellOrderItem) public sellOrderList;

    event ItemListed(address indexed seller, uint256 price);
    event ItemSold(address indexed buyer, uint256 price);

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
            "Cannot buy non sold token"
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
    }

    function listItemOnAuction() public {
        /**
            выставка предмета на продажу в аукционе.

            Аукцион длится 3 дня с момента открытия.
            В течении трех дней аукцион не может быть отменен.

            После трех дней, если набирается больше двух заявок (?почему две нельзя или можно?),
            то аукцион успешен: токены идут к создателю аукциона, а нфт отправляет в ?последнему? биддеру.

            В противном случае(? когда не набралось более двух заявок?), токены отправляются к биддеру, а нфт остается у создателя.

            1. Получается, что пользователи будут присылать токены? 
                ? Можно ли ввести одну переменную, которая будет перезатираться, если биддер предложит большую цену?
         */
    }

    function makeBid() public {
        /**
            сделать ставку на предмет аукциона с определенным id
         */
    }

    function finishAution() public {
        /**
            завершить аукцион и отраваить нфт победителю
         */
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
