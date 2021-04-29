const { expect } = require("chai");
const { ethers } = require("hardhat");
const tokenJson = require("./inc/token.json");
const deployJson = require("./inc/deploy.json");
const { advanceBlockTo } = require("./inc/time");
const { BigNumber } = require("ethers");

const uniRouter = "0xED7d5F38C79115ca12fe6C0041abb22F0A06C300";
const gVaultJson = require("../artifacts/contracts/vaults/gVault.sol/gVault.json");
const uniJson = require("../artifacts/interfaces/uniswap/Uni.sol/Uni.json");
const strategyJson = require("../artifacts/contracts/strategies/StrategyChannels.sol/StrategyChannels.json");
const WHT = "0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F";
const Controller = "0xd5BE05a54E86AC41c6E46f70c7b75F4c337161f5";
const ControllerJson = require("../artifacts/contracts/controllers/Controller.sol/Controller.json");
const BASE_TEN = 10;
const { TOKENS } = tokenJson;
function getBigNumber(amount, decimals = 18) {
    return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals));
}

beforeAmount = ethers.utils.parseEther("999");
describe("测试", function () {
    before(async function () {
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.bob = this.signers[1];
        this.carol = this.signers[2];
        this.dev = this.signers[3];
        this.minter = this.signers[4];
        this.Controller = await ethers.getContractAt(ControllerJson.abi, Controller);
        this.BalanceChecker = await ethers.getContractFactory("BalanceChecker");
        this.token = [];
        this.vaults = [];
        this.strategies = [];
    });

    it("初始化Token", async function () {
        for (let i = 0; i < TOKENS.length; i++) {
            this.token[TOKENS[i].symbol] = await ethers.getContractAt(
                gVaultJson.abi,
                TOKENS[i].address
            );
            expect(await this.token[TOKENS[i].symbol].name()).to.equal(TOKENS[i].name);
        }
        this.balanceChecker = await this.BalanceChecker.deploy();
        await this.balanceChecker.deployed();
    });

    it("Controller", async function () {
        console.log(await this.Controller.governance());
        prevStrategy = await this.Controller.strategies(this.token.MDX.address);
        // expect(await this.vaults[want].balance()).to.gte(depositAmount);
    });

    it("当前策略", async function () {
        currentStrategy = await this.Controller.strategies(this.token.MDX.address);
        CurrentStrategy = await ethers.getContractAt(strategyJson.abi, currentStrategy);
    });

    it("验证当前策略", async function () {
        expect(prevStrategy).to.equal(currentStrategy);
        const bal = await CurrentStrategy.balanceOf();
        console.log("   balanceOf:", ethers.utils.formatEther(bal).toString());
    });

    it("实例化Vault", async function () {
        vaults = await this.Controller.vaults(this.token.MDX.address);
        Vault = await ethers.getContractAt(gVaultJson.abi, vaults);
    });

    for (let i = 0; i < deployJson.MDX.length; i++) {
        it("部署策略", async function () {
            thisStrategy = deployJson.MDX[i].strategy;
            param = deployJson.MDX[i].param;
            this.strategy = await ethers.getContractFactory(thisStrategy);
            this.Strategy = await this.strategy.deploy(...param);
            await this.Strategy.deployed();
        });

        it("设置策略", async function () {
            prevStrategy = this.Strategy.address;
            param = [this.token.MDX.address, this.Strategy.address];
            console.log("   param:", param);
            await this.Controller.connect(this.bob).approveStrategy(...param);
            await this.Controller.connect(this.bob).setStrategy(...param);
            expect(await this.Controller.strategies(this.token.MDX.address)).to.equal(
                this.Strategy.address
            );
        });

        it("验证Vault", async function () {
            const available = await Vault.available();
            expect(available).to.gt(getBigNumber("0"));
            console.log(
                "   available:",
                ethers.utils.formatEther(available).toString()
            );
        });

        it("earn", async function () {
            await Vault.earn();
            expect(await Vault.available()).to.equal(getBigNumber("0"));
        });

        it("验证Vault", async function () {
            const available = await Vault.available();
            expect(available).to.equal(getBigNumber("0"));
            console.log(
                "   available:",
                ethers.utils.formatEther(available).toString()
            );
        });

        it("当前策略", async function () {
            currentStrategy = await this.Controller.strategies(this.token.MDX.address);
            CurrentStrategy = await ethers.getContractAt(
                strategyJson.abi,
                currentStrategy
            );
        });

        it("验证当前策略", async function () {
            expect(prevStrategy).to.equal(currentStrategy);
            const bal = await CurrentStrategy.balanceOf();
            console.log("   balanceOf:", ethers.utils.formatEther(bal).toString());
        });
    }
});
