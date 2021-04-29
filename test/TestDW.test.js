const { expect } = require("chai");
const { ethers } = require("hardhat");
const tokenJson = require("./inc/token.json");
const { advanceBlockTo } = require("./inc/time");
const { BigNumber } = require("ethers");

const uniRouter = "0xED7d5F38C79115ca12fe6C0041abb22F0A06C300";
const gVaultJson = require("../artifacts/contracts/vaults/gVault.sol/gVault.json");
const uniJson = require("../artifacts/interfaces/uniswap/Uni.sol/Uni.json");
const MDX = "0x25D2e80cB6B86881Fd7e07dd263Fb79f4AbE033c";
const WHT = "0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F";
const BASE_TEN = 10;
function getBigNumber(amount, decimals = 18) {
    return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals));
}

beforeAmount = ethers.utils.parseEther("100");
describe("测试存取款", function () {
    before(async function () {
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.bob = this.signers[1];
        this.carol = this.signers[2];
        this.dev = this.signers[3];
        this.minter = this.signers[4];
        this.testDW = await ethers.getContractFactory("TestDW");
        this.token = await ethers.getContractAt(
            gVaultJson.abi,
            MDX
        );
        this.TestDW = await this.testDW.deploy();
        await this.TestDW.deployed();
    });


    it("初始化Swap", async function () {
        this.uni = await ethers.getContractAt(uniJson.abi, uniRouter);
    });
    it("兑换", async function () {
        param = [
            "0",
            [WHT, MDX],
            this.alice.address,
            "99999999999999999999999999",
        ];
        await this.uni.swapExactETHForTokens(...param, {
            value: ethers.utils.parseEther("100"),
        });
    });

    it("验证数量", async function () {
        depositAmount = await this.token.balanceOf(this.alice.address);
        expect(depositAmount).to.gt(getBigNumber("0"));
    });

    it("批准", async function () {
        await this.token.approve(
            this.TestDW.address,
            depositAmount
        );
    });
    it("验证批准", async function () {
        expect(
            await this.token.allowance(
                this.alice.address,
                this.TestDW.address
            )
        ).to.equal(depositAmount);
    });
    it("存款", async function () {
        console.log(
            "   depositAmount:",
            ethers.utils.formatEther(depositAmount).toString()
        );
        let tx = await this.TestDW.deposit(depositAmount);
    });

    it("验证数量", async function () {
        expect(await this.token.balanceOf(this.TestDW.address)).to.equal(depositAmount);
    });

    it("存款", async function () {
        let tx = await this.TestDW.earn(depositAmount);
    });
    it("advanceBlockTo", async function () {
        await advanceBlockTo(100000);
    });
    
    it("strategy.balanceOfPool", async function () {
        balanceOfPool = await this.TestDW.balanceOfPool();
        expect(balanceOfPool).to.gte(depositAmount);
    });

    it("取款", async function () {
        let tx = await this.TestDW.withdraw(balanceOfPool);
    });
});
