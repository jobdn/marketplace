//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";

import "./ERC721Token.sol";

contract Marketplace {
    // Как проверять енум, если я буду делать проверку на статус
    enum ItemStatus {
        PAID,
        NOT_PAID
    }

    // Как называется товар на маркет плейсе?
    struct MarketplaceItem {
        address seller;
        uint256 price;
        ItemStatus status;
    }

    address public ERC721_TOKEN;
    using Counters for Counters.Counter;
    Counters.Counter private _ids;
    mapping(uint256 => MarketplaceItem) public orderList;

    constructor(address nftTokenAddress) {
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
