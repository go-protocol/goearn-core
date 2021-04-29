const { expect } = require("chai");
const { ethers } = require("hardhat");
const tokenJson = require("./inc/token.json");
const { advanceBlockTo } = require("./inc/time");
const { BigNumber } = require("ethers");

const uniRouter = "0xED7d5F38C79115ca12fe6C0041abb22F0A06C300";
const gVaultJson = require("../artifacts/contracts/vaults/gVault.sol/gVault.json");
const uniJson = require("../artifacts/interfaces/uniswap/Uni.sol/Uni.json");
const WHT = "0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F";
const BASE_TEN = 10;
const thisStrategy = "StrategyCoinWind";
const { TOKENS } = tokenJson;
function getBigNumber(amount, decimals = 18) {
    return BigNumber.from(amount).mul(BigNumber.from(BASE_TEN).pow(decimals));
}

beforeAmount = ethers.utils.parseEther("999");
describe("测试" + thisStrategy, function () {
    before(async function () {
        this.signers = await ethers.getSigners();
        this.alice = this.signers[0];
        this.bob = this.signers[1];
        this.carol = this.signers[2];
        this.dev = this.signers[3];
        this.minter = this.signers[4];
        this.Controller = await ethers.getContractFactory("Controller");
        this.gVault = await ethers.getContractFactory("gVault");
        this.gVaultHT = await ethers.getContractFactory("gVaultHT");
        this.strategy = await ethers.getContractFactory(thisStrategy);
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

    it("部署控制器", async function () {
        param = [
            //构造函数的参数
            this.alice.address,
            uniRouter,
        ];
        this.controller = await this.Controller.deploy(...param);
        await this.controller.deployed();
    });

    it("部署 Vault", async function () {
        for (let i = 0; i < TOKENS.length; i++) {
            if (TOKENS[i].symbol !== "WHT") {
                this.vaults[TOKENS[i].symbol] = await this.gVault.deploy(
                    TOKENS[i].address,
                    this.controller.address
                );
            } else {
                this.vaults[TOKENS[i].symbol] = await this.gVaultHT.deploy(
                    this.controller.address
                );
            }
            await this.vaults[TOKENS[i].symbol].deployed();
        }
    });

    it("设置Vault", async function () {
        for (let i = 0; i < TOKENS.length; i++) {
            param = [TOKENS[i].address, this.vaults[TOKENS[i].symbol].address];
            await this.controller.setVault(...param);
            expect(await this.controller.vaults(TOKENS[i].address)).to.equal(
                this.vaults[TOKENS[i].symbol].address
            );
        }
    });

    it("初始化Swap", async function () {
        this.uni = await ethers.getContractAt(uniJson.abi, uniRouter);
        expect(await this.uni.WHT()).to.equal(
            "0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F"
        );
    });

    for (let i = 0; i < TOKENS.length; i++) {
        it("部署策略", async function () {
            want = TOKENS[i].symbol;
            console.log("   want:", want);
            param = [
                //构造函数的参数
                this.controller.address,
                this.token[want].address
            ];
            this.strategies[want] = await this.strategy.deploy(...param);
            await this.strategies[want].deployed();
        });

        it("设置策略", async function () {
            param = [this.token[want].address, this.strategies[want].address];
            await this.controller.approveStrategy(...param);
            await this.controller.setStrategy(...param);
            expect(await this.controller.strategies(this.token[want].address)).to.equal(
                this.strategies[want].address
            );
        });

        it("兑换want", async function () {
            if (want !== "WHT") {
                param = [
                    "0",
                    [WHT, this.token[want].address],
                    this.alice.address,
                    "99999999999999999999999999",
                ];
                await this.uni.swapExactETHForTokens(...param, {
                    value: beforeAmount,
                });
            }
        });

        it("验证want数量", async function () {
            if (want !== "WHT") {
                depositAmount = await this.token[want].balanceOf(this.alice.address);
                expect(depositAmount).to.gt(getBigNumber("0"));
            } else {
                depositAmount = beforeAmount;
            }
        });

        it("批准", async function () {
            if (want !== "WHT") {
                await this.token[want].approve(
                    this.vaults[want].address,
                    depositAmount
                );
            }
        });
        it("验证批准", async function () {
            if (want !== "WHT") {
                expect(
                    await this.token[want].allowance(
                        this.alice.address,
                        this.vaults[want].address
                    )
                ).to.equal(depositAmount);
            }
        });
        it("存款", async function () {
            console.log(
                "   depositAmount:",
                ethers.utils.formatEther(depositAmount).toString()
            );
            if (want !== "WHT") {
                let tx = await this.vaults[want].deposit(depositAmount);
            } else {
                let tx = await this.vaults[want].deposit(depositAmount, {
                    value: depositAmount,
                });
            }
        });


        it("advanceBlockTo", async function () {
            await advanceBlockTo(100000 * (i + 1));
        });

        it("strategy.harvest", async function () {
            let tx = await this.strategies[want].harvest();
            // console.log(await tx.wait());
        });

        it("vault.balance", async function () {
            expect(await this.vaults[want].balance()).to.gte(depositAmount);
        });

        it("balanceOf", async function () {
            balanceOf = await this.strategies[want].balanceOf();
            expect(balanceOf).to.gt("0");
            console.log(
                "   balanceOf:",
                ethers.utils.formatEther(balanceOf).toString()
            );
        });

        it("balance", async function () {
            balance = await this.vaults[want].balance();
            console.log("   balance:", ethers.utils.formatEther(balance).toString());
        });

        it("取款", async function () {
            let tx = await this.vaults[want].withdrawAll();
        });

        it("验证取款", async function () {
            if (want !== "WHT") {
                afterAmount = await this.token[want].balanceOf(this.alice.address);
            } else {
                afterAmount = await this.balanceChecker.balanceOfHT(this.alice.address);
            }
            expect(afterAmount).to.gte(depositAmount);
        });

        it("批准uni", async function () {
            if (want !== "WHT") {
                await this.token[want].approve(this.uni.address, afterAmount);
            }
        });

        it("兑换ETH", async function () {
            if (want !== "WHT") {
                param = [
                    afterAmount,
                    "0",
                    [this.token[want].address, WHT],
                    this.alice.address,
                    "99999999999999999999999999",
                ];
                await this.uni.swapExactTokensForETH(...param);
            }
        });

        it("验证ETH", async function () {
            balanceOfHT = await this.balanceChecker.balanceOfHT(this.alice.address);
            console.log('   balanceOfHT:',ethers.utils.formatEther(balanceOfHT).toString());
            balanceOfHT = await this.balanceChecker.balanceOfHT(this.strategies[want].address);
            console.log('   strategies HT:',ethers.utils.formatEther(balanceOfHT).toString());
        });
    }
});
