const FoMo3d = artifacts.require("FoMo3Dlong");
const BN = require("bn.js");

contract("FoMo3d", (accounts) => {
    let instance;

    beforeEach('set new instance', async() => {
        instance = await FoMo3d.new();
        await instance.activate();
    });

    it("shoud activate game", async() => {
        const activated = await instance.activated_.call();
        assert.equal(activated, true, "game not activated correctly");
    });
    it("buy 1 eth by account[1]", async() => {
        await instance.sendTransaction({from: accounts[1], value: web3.utils.toWei('1', 'ether')});
        const roundInfo = await instance.getRoundInfo(0);
        assert.equal(roundInfo[1], accounts[1], 'last buy address');
        console.log(roundInfo[5].toString());
        assert.equal(roundInfo[6].eq(new BN(web3.utils.toWei('1', 'ether'))), true, 'total eth');
    });
    it("account[1] buy 1 eth, account[2] buy 2 eth", async() => {
        await instance.sendTransaction({from: accounts[1], value: web3.utils.toWei('1', 'ether')});
        await instance.sendTransaction({from: accounts[2], value: web3.utils.toWei('2', 'ether')});
        const roundInfo = await instance.getRoundInfo(0);
        assert.equal(roundInfo[1], accounts[2], 'last buy address');
        console.log(roundInfo[5].toString());
        assert.equal(roundInfo[6].eq(new BN(web3.utils.toWei('3', 'ether'))), true, 'total eth');
        assert.equal(roundInfo[7].gte(new BN(web3.utils.toWei('1.5', 'ether'))), true, 'total win eth');
    });
});