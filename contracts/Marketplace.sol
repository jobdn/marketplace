//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./ERC721Token.sol";

contract Marketplace is AccessControl {
    // Как проверять енум, если я буду делать проверку на статус
    enum ItemStatus {
        PAID,
        NOT_PAID
    }

    struct SellOrderItem {
        address seller;
        uint256 price;
        ItemStatus status;
    }

    address public ERC721_TOKEN;
    using Counters for Counters.Counter;
    Counters.Counter private _ids;
    mapping(uint256 => SellOrderItem) public sellOrderList;

    event ItemListed(address indexed seller, uint256 price);
    event ItemSold(address indexed buyer, uint256 price);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setERC721TokenAddress(address nftTokenAddress) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "You cannot set ERC721 address"
        );
        ERC721_TOKEN = nftTokenAddress;
    }

    function createItem(string memory metadata, address owner) public {
        _ids.increment();
        ERC721Token(ERC721_TOKEN).mint(_ids.current(), owner, metadata);
    }

    function listItem(uint256 tokenId, uint256 price) public {
        /**
            выставка на продажу предмета
         */
        ERC721Token(ERC721_TOKEN).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        sellOrderList[tokenId] = SellOrderItem({
            seller: msg.sender,
            price: price,
            status: ItemStatus.NOT_PAID
        });

        emit ItemListed(msg.sender, price);
    }

    function buyItem() public {
        /**
            покупка предмета.
         */
    }

    function cancel() public {
        /**
            отмена продажи выставленного предмета
         */
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
}
