## FoMo3d简化版本

### 说明

通过[fomo3d_clone](https://github.com/reedhong/fomo3d_clone)项目改造而成，去除了队伍以及与部分与权限有关的逻辑，将未开源的代码逻辑替换了为常量值，修改了分红规则等逻辑。

`truffle compile`编译后可以使用`truffle migrate`一键部署到私有链(Ganache、testrpc等)，在部署脚本中已经通过借助`async\await`在合约部署到链上后自动激活了游戏。

测试脚本仅包含了简单的测试，之后将会用`openzepplin test helpers`重写

### 相关命令

编译合约

`truffle compile`

一键部署到私有链环境

`truffle migrate`

运行测试代码

`truffle test`



