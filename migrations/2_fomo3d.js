const FoMo3Dlong = artifacts.require("FoMo3Dlong");

module.exports = async function(deployer, network, accounts) {
    await deployer.deploy(FoMo3Dlong);
    let instance = await FoMo3Dlong.deployed();
    await instance.activate({gasPrice: web3.utils.toWei('10', 'gwei')});

    // deployer.then(function() {
    //     return FoMo3Dlong.deployed();
    // }).then(function(instance) {
    //     // 部署后直接激活
    //     instance.activate({gasPrice: web3.utils.toWei('10', 'gwei')});
    // });
};

