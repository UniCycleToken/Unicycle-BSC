const {
  BN,
  ether,
  expectRevert,
  time,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const { increaseTime } = require('../utils/increaseTime');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');

contract('UNIC test', async ([owner, burner, holder]) => {
  const startTime = Math.floor(Date.now() / 1000) - 86400;

  beforeEach(async () => {
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
  });

  it('checking the unic token parameters', async () => {
    const blocktime = (await web3.eth.getBlock()).timestamp;
    console.log(blocktime);
    await time.increase(time.duration.days(1));
  });
  it('checking the unic token parameters', async () => {
    const blocktime = (await web3.eth.getBlock()).timestamp;
    console.log(time.duration.days(1).toString());
  });
});
