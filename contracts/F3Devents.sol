pragma solidity >=0.4.24 <0.6.0;

contract F3Devents {
    event onUpdateMask(
        uint256 rID,
        address addr,
        uint256 eth,
        uint256 keys,
        uint dust
    );

    event onBuyKey(
        address indexed addr,
        uint256 indexed rID,
        uint256 indexed buy_time,
        uint256 eth,
        uint256 key
    );
    
	// fired whenever theres a withdraw
    event onWithdraw
    (
        address indexed player_addr,
        uint256 ethOut,
        uint256 timeStamp
    );
}