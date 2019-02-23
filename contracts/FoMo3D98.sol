pragma solidity >=0.4.24 <0.6.0;

import {F3Devents} from "./F3Devents.sol";
import {Console} from "./Console.sol";
import {F3Ddatasets} from "./library/F3Ddatasets.sol";
import {SafeMath} from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import {Ownable} from "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import {Address} from "./library/Address.sol";
import {F3DKeysCalcLong} from "./library/F3DKeysCalcLong.sol";


contract FoMo3Dlong is F3Devents, Ownable, Console {
    using Address for address;
    using Address for address payable;
    using SafeMath for *;
    using F3DKeysCalcLong for uint256;    
	
    string constant public name = "FoMo3D Simple Version";
    string constant public symbol = "F3DSimple";
    uint256 constant private rndGap = 3 minutes;         // 轮次间隔 
    uint256 constant private rndInit_ = 10 minutes;                // round timer starts at this
    uint256 constant private rndInc_ = 30 seconds;              // every full key purchased adds this much to the timer
    uint256 constant private rndMax_ = 11 minutes;                // max length a round timer can be

    /* 收入分配参数 */
    uint256 private fee_win = 50;   // win 奖池
    uint256 private fee_pool = 40;  // pool 分红奖池
    uint256 private fee_com = 10;   // 社区

    uint256 private com_balance = 0;    // 社区资金余额
    uint256 public init_rID = 10;       // 初始轮次
    uint256 public rID_;    // round id number / total rounds that have happened
    mapping (address => F3Ddatasets.Player) public addr2pData;  // (addr => data) player data
    // (addr => rID => data) player round data by player addr & round id
    mapping (address => mapping (uint256 => F3Ddatasets.PlayerRounds)) public addrxrID2rData;
    mapping (uint256 => F3Ddatasets.Round) public rID2rData;   // (rID => data) round data

    constructor() public {}

    /**
     * @dev used to make sure no one can interact with contract until it has 
     * been activated. 
     */
    modifier isActivated() {
        require(activated_ == true, "its not ready yet.  check ?eta in discord"); 
        _;
    }

    modifier isUnActivated() {
        require(activated_ == false, "its already start"); 
        _;
    }
    
    /**
     * @dev prevents contracts from interacting with fomo3d 
     */
    modifier isHuman() {
        // 消息调用者code size为0不一定就不是合约，在构造函数中发起调用code size就是0，因为此时合约代码还不存在
        require(msg.sender.isContract() == false, "sorry humans only");
        // 如下调用链 A->B->C，在C中 msg.sender == B, tx.origin == A, 即tx.origin表示完整调用链的发起者地址，而msg,sender表示当前消息的发送者地址
        require(msg.sender == tx.origin, "sorry humans only"); // solium-disable-line security/no-tx-origin
        _;
    }

    /**
     * @dev sets boundaries for incoming tx 
     */
    modifier isWithinLimits(uint256 _eth) {
        // require(_eth >= 1e15, "pocket lint: not a valid currency");
        require(_eth <= 1e23, "no vitalik, no");
        _;    
    }
    
    function() external isActivated isHuman isWithinLimits(msg.value) payable
    {   
        registerUser();        
        buyCore();
    }

    function getComBalance() external view isHuman onlyOwner returns(uint256) {
        return com_balance;
    }

    function withdrawComBalance() external onlyOwner {
        uint _com_balance = com_balance;
        com_balance = 0;
        msg.sender.transfer(_com_balance);
    }

    function depositCurrentRoundWin() external payable isActivated {
        rID2rData[rID_].win = msg.value.add(rID2rData[rID_].win);
    }

    /**
     * @dev withdraws all of your earnings.
     */
    function withdraw(address payable player_addr, uint256 rID) external isActivated isHuman onlyOwner
    {
        uint256 _eth;   // setup temp var for player eth
        // 只有当该轮次已结束才能提现
        if (rID2rData[rID].ended == true && addrxrID2rData[player_addr][rID].withdrawed == false)
        {
            addrxrID2rData[player_addr][rID].withdrawed = true;
			// get their earnings
            _eth = withdrawEarnings(player_addr, rID);
            
            // 发钱了！
            if (_eth > 0)
                player_addr.transfer(_eth);
                emit onWithdraw(player_addr, _eth, block.timestamp);
        }
    }
    
    /**
     * @dev return the price buyer will pay for next 1 individual key.
     * -functionhash- 0x018a25e8
     * 等于在当前基础上多卖出一个key收到的eth减去当前收到的eth
     * @return price for next key bought (in wei format)
     */
    function getBuyPrice() public view returns(uint256)
    {  
        // setup local rID
        uint256 _rID = rID_;
        // grab time
        uint256 _now = block.timestamp; // solium-disable-line
        
        // are we in a round?
        if (_now > rID2rData[_rID].strt && (_now <= rID2rData[_rID].end || (_now > rID2rData[_rID].end && rID2rData[_rID].last_player_addr == address(0))))
            return (rID2rData[_rID].keys.add(1e18)).ethRec(1e18);
        else // rounds over.  need price for new round
            return 7.5e13; // init
    }
    
    /**
     * @dev returns time left.  dont spam this, you'll ddos yourself from your node 
     * provider
     * -functionhash- 0xc7e284b8
     * @return time left in seconds
     */
    function getTimeLeft() public view returns(uint256)
    {
        // setup local rID
        uint256 _rID = rID_;
        
        // grab time
        uint256 _now = block.timestamp; // solium-disable-line
        
        if (_now < rID2rData[_rID].end)
            if (_now > rID2rData[_rID].strt)
                return rID2rData[_rID].end.sub(_now);
            else
                return rID2rData[_rID].strt.sub(_now);
        else
            return(0);
    }
    
    /**
     * @dev returns player earnings per vaults 
     * -functionhash- 0x63066434
     * @return winnings vault
     * @return pool vault
     * @return affiliate vault
     */
    // function getPlayerVaults(address addr)
    //     public
    //     view
    //     returns(uint256 ,uint256)
    // {
    //     // if round has ended.  but round end has not been run (so contract has not distributed winnings)
    //     if (block.timestamp > rID2rData[rID_].end && rID2rData[rID_].ended == false && rID2rData[rID_].last_player_addr != address(0))
    //     {
    //         // if player is winner 
    //         if (rID2rData[rID_].last_player_addr == addr)
    //         {
    //             return
    //             (
    //                 addr2pData[addr].win.add(rID2rData[rID_].win),
    //                 addr2pData[addr].pool.add(getPlayerVaultsHelper(addr, rID_).sub(addrxrID2rData[addr][rID_].mask))
    //             );
    //         // if player is not the winner
    //         } else {
    //             return
    //             (
    //                 addr2pData[addr].win,
    //                 addr2pData[addr].pool.add(getPlayerVaultsHelper(addr, rID_).sub(addrxrID2rData[addr][rID_].mask))
    //             );
    //         }
    //     // if round is still going on, or round has ended and round end has been ran
    //     } else {
    //         return
    //         (
    //             addr2pData[addr].win,
    //             addr2pData[addr].pool.add(calcUnMaskedEarnings(addr, addr2pData[addr].lrnd))
    //         );
    //     }
    // }
    
    /**
     * solidity hates stack limits.  this lets us avoid that hate 
     */
    // function getPlayerVaultsHelper(address addr, uint256 _rID)
    //     private
    //     view
    //     returns(uint256)
    // {
    //     return rID2rData[_rID].mask.add(
    //         rID2rData[_rID].win.mul(1e18).div(rID2rData[_rID].keys)
    //         ).mul(addrxrID2rData[addr][_rID].keys).div(1e18);
    // }

    /**
     * @dev returns player info based on address.  if no address is given, it will 
     * use msg.sender 
  
     * @return player ID 
     * @return keys owned (current round)
     * @return winnings vault
     * @return pool vault 
	 * @return player round eth
     */
    function getPlayerInfoByAddressAndrID(address addr, uint256 rID)
        public 
        view 
        returns(address, uint256, uint256, uint256, uint256)
    {
        if (addr == address(0))
            addr == msg.sender;
        if (rID == 0)
            rID = addr2pData[addr].lrnd;
        
        return
        (
            addr,                               
            addr2pData[addr].back_eth,
            addrxrID2rData[addr][rID].keys,         
            calcUnMaskedEarnings(addr, rID),       
            addrxrID2rData[addr][rID].eth         
        );
    }

    /**
     * @dev logic runs whenever a buy order is executed.  determines how to handle 
     * incoming eth depending on if we are in an active round or not
     */
    function buyCore() private
    {
        // grab time
        uint256 _now = block.timestamp;     // solium-disable-line security/no-block-members

        // if round has ended
        if (rID2rData[rID_].ended == true)
            revert("Round has ended, can not reveive eth now");
        // now < start
        else if (_now < rID2rData[rID_].strt) {
            revert("Round has not start, can not reveive eth now");
        } else if (_now >= rID2rData[rID_].strt && _now <= rID2rData[rID_].end) {
            // start <= now <= end, round is active
            core();
        } else {
            // now > end and end round needs to be ran
            endRoundAndSetWin(rID_);
            // put eth back to player
            addr2pData[msg.sender].back_eth = addr2pData[msg.sender].back_eth.add(msg.value);
        }
    }
    
    /**
     * @dev this is the core logic for any buy/reload that happens while a round 
     * is live. 购买key
     */
    function core() private
    {
        uint eth = msg.value;
        address addr = msg.sender;

        if (eth == 0)
            return;

        // if player is new to this round
        if (addrxrID2rData[addr][rID_].keys == 0)
            addr2pData[addr].lrnd = rID_;

        // mint the new keys 铸造新的key，单位wei
        uint256 _keys = rID2rData[rID_].eth.keysRec(eth);
        emit onBuyKey(addr, rID_, block.timestamp, eth, _keys);
        
        // if they bought at least 1 whole key,下面这个数字等价于 1 eth 对应的 wei 的量
        if (_keys >= 1e18)
        {
            updateTimer(_keys, rID_);

            // 重置最后一个购买者
            if (rID2rData[rID_].last_player_addr != addr)
                rID2rData[rID_].last_player_addr = addr;  
        }
        
        // update player ,增加keys和eth
        addrxrID2rData[addr][rID_].keys = _keys.add(addrxrID2rData[addr][rID_].keys);
        addrxrID2rData[addr][rID_].eth = eth.add(addrxrID2rData[addr][rID_].eth);
        
        // update round
        rID2rData[rID_].keys = _keys.add(rID2rData[rID_].keys);
        rID2rData[rID_].eth = eth.add(rID2rData[rID_].eth);

        // 分配此次购买的eth
        distributeExternal(eth);
        distributeInternal(rID_, addr, eth, _keys);
    }

    /**
     * @dev 计算玩家在某轮次游戏中可以获得的分红
     * @return earnings in wei format
     */
    function calcUnMaskedEarnings(address addr, uint256 rID) private view returns(uint256)
    {
        return
            (
                rID2rData[rID].mask.mul(addrxrID2rData[addr][rID].keys) / 1e18
            ).sub(addrxrID2rData[addr][rID].mask);
    }
    
    /** 
     * @dev returns the amount of keys you would get given an amount of eth. 
     * -functionhash- 0xce89c80c
     * @param _rID round ID you want price for
     * @param _eth amount of eth sent in 
     * @return keys received 
     */
    function calcKeysReceived(uint256 _rID, uint256 _eth)
        public
        view
        returns(uint256)
    {
        // grab time
        uint256 _now = block.timestamp;     // solium-disable-line
        
        // are we in a round?
        if (_now > rID2rData[_rID].strt && (_now <= rID2rData[_rID].end || (_now > rID2rData[_rID].end && rID2rData[_rID].last_player_addr == address(0))))
            return ( (rID2rData[_rID].eth).keysRec(_eth) );
        else // rounds over.  need keys for new round
            return _eth.keys();
    }
    
    /** 
     * @dev returns current eth price for X keys.  
     * -functionhash- 0xcf808000
     * @param _keys number of keys desired (in 18 decimal format)
     * @return amount of eth needed to send
     */
    function iWantXKeys(uint256 _keys)
        public
        view
        returns(uint256)
    {
        _keys = _keys.mul(1e18);
        // grab time
        uint256 _now = block.timestamp;
        
        // are we in a round?
        if (_now > rID2rData[rID_].strt && (_now <= rID2rData[rID_].end || (_now > rID2rData[rID_].end && rID2rData[rID_].last_player_addr == address(0))))
            return ( (rID2rData[rID_].keys.add(_keys)).ethRec(_keys) );
        else // rounds over.  need price for new round
            return _keys.eth();
    }

    /**
     * @dev 注册新用户
     * @return pID 
     */
    function registerUser() private
    {
        F3Ddatasets.Player storage player = addr2pData[msg.sender];

        // if player is new to this version of fomo3d
        if (player.addr == address(0))
            player.addr = msg.sender;
    }
    
    /**
     * @dev 结束x轮游戏,设置赢家win数据
     */
    function endRoundAndSetWin(uint256 rID) private
    {   
        // 如果已经结束了，就直接返回
        if (rID2rData[rID].ended == true)
            return;

        rID2rData[rID].ended = true;

        // 获取最后一个玩家地址
        address win_address = rID2rData[rID].last_player_addr;
        // grab current round win amount
        uint256 win = rID2rData[rID].win;

        // 设置赢家的rounddata数据和player数据(win字段)
        addrxrID2rData[win_address][rID].win = win;
        
        // 如果当前轮次游戏结束，就开启下一轮，间隔rndGap
        if (rID == rID_){
            rID_++;
            rID2rData[rID_].strt = block.timestamp.add(rndGap);     // solium-disable-line security/no-block-members
            rID2rData[rID_].end = rID2rData[rID_].strt.add(rndInit_);
        }
    }
    
    /**
     * @dev 计算用户在某轮次的分红收益并记录到playerRound.pool中
     * 用户在购买key之后的某一时段提现已产生的收益，之前已购买的key依然能为用户带来后续的分红收益
     */
    function updatePlayerRoundPool(address addr, uint256 rID) private 
    {
        uint256 _earnings = calcUnMaskedEarnings(addr, rID);
        if (_earnings > 0)
        {
            // put in player round pool
            addrxrID2rData[addr][rID].pool = _earnings;
            // zero out their earnings by updating mask, 没错，根据用户分红收益计算公式，直接往playerRound.mask上加已提现收益即可
            // 非常重要，防止重复提现某轮次的分红, 目前不需要了，因为已经限制了玩家在一轮中只能提现一次
            // addrxrID2rData[addr][rID].mask = _earnings.add(addrxrID2rData[addr][rID].mask);
        }
    }
    
    /**
     * @dev updates round timer based on number of whole keys bought.
     */
    function updateTimer(uint256 _keys, uint256 _rID)
        private
    {
        // grab time
        uint256 _now = block.timestamp; // solium-disable-line
        
        // calculate time based on number of keys bought
        uint256 _newTime;

        if (_now > rID2rData[_rID].end && rID2rData[_rID].last_player_addr == address(0))
            _newTime = _keys.div(1e18).mul(rndInc_).add(_now);
        else
            _newTime = _keys.div(1e18).mul(rndInc_).add(rID2rData[_rID].end);
        
        // compare to max and set new end time，倒计时最大时间只能是当前之后2小时
        if (_newTime < rndMax_.add(_now))
            rID2rData[_rID].end = _newTime;
        else
            rID2rData[_rID].end = rndMax_.add(_now);
    }

    /**
     * @dev distributes eth based on fees to com
     * 每次key购买的费用分给外部的部分->社区
     */
    function distributeExternal(uint256 _eth) private
    {
        // pay fee_com% out to community rewards
        com_balance = com_balance.add(_eth.mul(fee_com).div(100));     
    }
    
    /**
     * @dev distributes eth based on fees to pool and win
     * 购买key的费用分发给内部的部分，包括 win 和 分红池pool
     */
    function distributeInternal(uint256 _rID, address addr, uint256 _eth,  uint256 _keys) private
    {
        uint eth = _eth;

        // key持有者分红pool
        uint256 pool = _eth.mul(fee_pool).div(100);
        
        // update eth balance (eth = eth - com)
        eth = _eth.mul(90).div(100);
        
        // calculate win 获胜者奖池
        uint256 win = eth.sub(pool);
        
        // distribute pool share (thats what updateMasks() does) and adjust
        // balances for dust.
        uint256 _dust = updateMasks(_rID, addr, pool, _keys);
        emit onUpdateMask(_rID, addr, eth, _keys, _dust);

        //分发该轮游戏的Key分红奖励后可能会剩余一点, 这里可以emit log记录
        if (_dust > 0)
            pool = pool.sub(_dust);

        rID2rData[_rID].pool = pool.add(rID2rData[_rID].pool);
        // add eth and dust to win
        rID2rData[_rID].win = win.add(_dust).add(rID2rData[_rID].win);
    }

    /**
     * @dev updates masks for round and player when keys are bought
     * @return dust left over 
     */
    function updateMasks(uint256 _rID, address addr, uint256 pool, uint256 _keys) private returns(uint256)
    {
        /* MASKING NOTES
            earnings masks are a tricky thing for people to wrap their minds around.
            the basic thing to understand here.  is were going to have a global
            tracker based on profit per share for each round, that increases in
            relevant proportion to the increase in share supply.
            
            the player will have an additional mask that basically says "based
            on the rounds mask, my shares, and how much i've already withdrawn,
            how much is still owed to me?"
        */
        
        // calc profit per key & round mask based on this buy:  (dust goes to win)
        // 更新 round.mask
        F3Ddatasets.Round storage round_data = rID2rData[_rID];
        uint256 _ppt = (pool.mul(1e18)) / (round_data.keys);   // todo 为什么这里pool要再乘1e18？
        round_data.mask = _ppt.add(round_data.mask);
        
        // 更新 playerRound.mask
        uint256 _pearn = (_ppt.mul(_keys)) / (1e18);
        addrxrID2rData[addr][_rID].mask = round_data.mask.mul(_keys).div(1e18).sub(_pearn).add(addrxrID2rData[addr][_rID].mask);
        
        // calculate & return dust, 可能会除不尽导致的偏差？
        return pool.sub(_ppt.mul(round_data.keys).div(1e18));
    }
    
    /**
     * @dev adds up unmasked earnings, & vault earnings, sets them all to 0
     * 返回可以某轮次提现的收益
     * @return earnings in wei format
     */
    function withdrawEarnings(address payable addr, uint256 rID) private returns(uint256)
    {
        // update player round pool
        updatePlayerRoundPool(addr, addr2pData[addr].lrnd);
        
        // 可提现金额 = win + 分红 + 可退的eth
        uint256 earnings = addrxrID2rData[addr][rID].win.add(addrxrID2rData[addr][rID].pool).add(addr2pData[addr].back_eth);
        // 现在是每轮结束后立刻提现，不再需要维护Player结构中的win和pool字段
        // if (_earnings > 0)
        // {
        //     addr2pData[addr].win = 0;
        //     addr2pData[addr].pool = 0;
        // }
        return earnings;
    }

    function getRoundInfo(uint256 _rID) external view isActivated
        returns(uint256, address, bool, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        uint256 rID = _rID;
        if (rID == 0)
            rID = rID_;

        return (
            rID,    // 0
            rID2rData[rID].last_player_addr,        // 1
            rID2rData[rID].ended,   // 2
            rID2rData[rID].end, // 3
            rID2rData[rID].strt,    // 4
            rID2rData[rID].keys,    // 5
            rID2rData[rID].eth, // 6
            rID2rData[rID].win, // 7
            rID2rData[rID].pool,    // 8
            rID2rData[rID].mask // 9
        );
    }

    // 设置初始游戏轮次参数
    function setInitRoundId(uint256 init_round_id) external onlyOwner isUnActivated {
        init_rID = init_round_id;
    }

    /** upon contract deploy, it will be deactivated.  this is a one time
     * use function that will activate the contract.  we do this so devs 
     * have time to set things up on the web end                            **/
    bool public activated_ = false;

    function activate() public onlyOwner
    {   
        // can only be ran once
        require(activated_ == false, "fomo3d already activated");
        
        // activate the contract 
        activated_ = true;
        
        // lets start first round
        rID_ = init_rID;
        rID2rData[rID_].strt = block.timestamp;     // solium-disable-line security/no-block-members
        rID2rData[rID_].end = block.timestamp + rndInit_;                 // solium-disable-line security/no-block-members
        log('activate game', rID_);
    }
}