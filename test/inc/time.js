const { ethers } = require("hardhat")

const { BigNumber } = ethers

exports.advanceBlock = () => {
  return ethers.provider.send("evm_mine", [])
}

exports.advanceBlockTo = async (blockNumber) => {
  for (let i = await ethers.provider.getBlockNumber(); i < blockNumber; i++) {
    await this.advanceBlock()
  }
}

exports.increase = async (value) => {
  await ethers.provider.send("evm_increaseTime", [Number(value)])
  await this.advanceBlock()
}

exports.latest = async () => {
  const block = await ethers.provider.getBlock("latest")
  return BigNumber.from(block.timestamp)
}

exports.advanceTimeAndBlock = async (time) => {
  await advanceTime(time)
  await this.advanceBlock()
}

exports.advanceTime = async (time) => {
  await ethers.provider.send("evm_increaseTime", [time])
}

exports.duration = {
  seconds: function (val) {
    return BigNumber.from(val)
  },
  minutes: function (val) {
    return BigNumber.from(val).mul(this.seconds("60"))
  },
  hours: function (val) {
    return BigNumber.from(val).mul(this.minutes("60"))
  },
  days: function (val) {
    return BigNumber.from(val).mul(this.hours("24"))
  },
  weeks: function (val) {
    return BigNumber.from(val).mul(this.days("7"))
  },
  years: function (val) {
    return BigNumber.from(val).mul(this.days("365"))
  },
}