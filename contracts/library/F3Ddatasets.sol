pragma solidity >=0.4.24 <0.6.0;

library F3Ddatasets {


    // 玩家数据
    struct Player {
        address addr;   // player address
        uint256 lrnd;   // last round played
        uint256 back_eth;   // 游戏结束时购买的eth，要返回给用户

        // 目前在结束时立刻提现，所以下面两个字段暂时用不到
        uint256 pool;   // 分红池分红，当提现时清空
        uint256 win;    // 获胜分红，当提现时清空
    }
    // 玩家在某一轮的数据
    struct PlayerRounds {
        uint256 keys;   // 在每一次玩家购买时更新
        uint256 eth;    // 累计参与的eth
        uint256 mask;   // player mask
        bool withdrawed;    // 提现标志位

        // 下面两个字段目前没有什么用，仅用于round结束时记录
        uint256 pool;   // 仅在最后游戏结束时计算
        uint256 win;    // 仅能在游戏结束时计算
    }
    // 某一轮的游戏数据
    struct Round {
        address last_player_addr;   // 最后一个玩家
        bool ended;     // has round end function been ran
        uint256 end;    // time ends/ended
        uint256 strt;   // time round started
        uint256 keys;   // total keys
        uint256 eth;    // total eth 投入的总eth，包括(win, pool, com)
        uint256 win;    // win奖池金额
        uint256 pool;   // pool奖池金额
        uint256 mask;   // global round mask
    }
}