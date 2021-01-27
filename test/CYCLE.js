const {
  BN,
  constants,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const { cycle } = require('./Utils');

const CYCLEToken = artifacts.require('CYCLEToken');
const Auction = artifacts.require('Auction');
const WETH = artifacts.require('WETH9');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('CYCLE test', async ([owner, burner, holder]) => {
  const startTime = Math.floor(Date.now() / 1000) - 86400;

  beforeEach(async () => {
    this.cycle = await CYCLEToken.new({ from: owner });
    this.weth = await WETH.new({ from: owner });
    this.factory = await UniswapV2Factory.new(owner, { from: owner });
    this.team = web3.eth.accounts.create();
    this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });
    this.auction = await Auction.new(this.cycle.address, this.router.address, startTime, this.team.address, { from: owner });
    await this.cycle.setAuction(this.auction.address, { from: owner });
    const pair = await this.factory.getPair(this.weth.address, this.cycle.address);
    await this.cycle.setCYCLEWETHAddress(pair, { from: owner });
  });

  it('setAuction and mint should fail', async () => {
    await expectRevert(this.cycle.setAuction(constants.ZERO_ADDRESS, { from: owner }), 'Zero address');
    await expectRevert(this.cycle.setCYCLEWETHAddress(constants.ZERO_ADDRESS, { from: owner }), 'Zero address');
    await expectRevert(this.cycle.setAuction(this.auction.address, { from: owner }), 'auction already set');
    await expectRevert(this.cycle.setCYCLEWETHAddress(this.auction.address, { from: owner }), 'CYCLEWETH already set');
    await expectRevert(this.cycle.mint(100, { from: owner }), 'Caller is not auction');
  });

  it('checking the cycle token parameters', async () => {
    expect(await this.cycle.name.call()).to.equal('UniCycle');
    expect(await this.cycle.symbol.call()).to.equal('CYCLE');
    expect(await this.cycle.decimals.call()).to.be.bignumber.equal(new BN('18'));
    expect(await this.cycle.totalSupply.call()).to.be.bignumber.equal(new BN('0'));
  });

  it('should correct set LP-Uni WETH/CYCLE', async () => {
    const pairAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
    expect(pairAddress).not.to.equal(constants.ZERO_ADDRESS);
    expect(await this.cycle.CYCLEWETHAddress.call()).to.equal(pairAddress);
  });

  it('check startAuction => setStartTime and mint', async () => {
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('0'));
    await this.auction.participate({ from: owner, value: 100000 });
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('100000'));
  });

  it('should fail if LP-Uni WETH/CYCLE not set', async () => {
    const cycle = await CYCLEToken.new({ from: owner });
    const auction = await Auction.new(this.cycle.address, this.router.address, startTime, this.team.address, { from: owner });
    await cycle.setAuction(auction.address, { from: owner });
    await expectRevert(auction.participate({ from: owner, value: 1 }), 'Caller is not auction');
  });

  describe('check blacklist', async () => {
    it('blacklist positive tests', async () => {
      await this.cycle.addToBlacklist(holder, { from: owner });
      expect(await this.cycle.isBlacklisted(holder)).to.equal(true);
      await this.cycle.removeFromBlacklist(holder, { from: owner });
      expect(await this.cycle.isBlacklisted(holder)).to.equal(false);
    });

    it('blacklist negative tests', async () => {
      await this.cycle.addToBlacklist(holder, { from: owner });
      await expectRevert(this.cycle.addToBlacklist(holder, { from: owner }), 'In black list');
      await this.cycle.removeFromBlacklist(holder, { from: owner });
      await expectRevert(this.cycle.removeFromBlacklist(holder, { from: owner }), 'Not blacklisted');
      await expectRevert.unspecified(this.cycle.removeFromBlacklist(burner, { from: holder }));
    });
  });
});
