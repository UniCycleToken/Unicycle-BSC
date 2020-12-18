const {
  BN,
  ether,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');
const WETH = artifacts.require('WETH9');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('UNIC test', async ([owner, burner, holder]) => {
  const startTime = Math.floor(Date.now() / 1000) - 86400;

  beforeEach(async () => {
    this.unic = await UNICToken.new({ from: owner });
    this.weth = await WETH.new({ from: owner });
    this.factory = await UniswapV2Factory.new(owner, { from: owner });
    await this.factory.createPair(this.weth.address, this.unic.address);
    const pairAddress = await this.factory.getPair(this.weth.address, this.unic.address);
    this.auction = await Auction.new(this.unic.address, pairAddress, startTime, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
  });

  it('checking the unic token parameters', async () => {
    expect(await this.unic.name.call()).to.equal('UNICToken');
    expect(await this.unic.symbol.call()).to.equal('UNIC');
    expect(await this.unic.decimals.call()).to.be.bignumber.equal(new BN('18'));
    expect(await this.unic.totalSupply.call()).to.be.bignumber.equal(new BN('0'));
  });

  it('check startAuction => setStartTime and mint', async () => {
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
    await this.auction.participate({ from: owner, value: 100000 });
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('2500000'));
  });

  describe('check blacklist', async () => {
    it('blacklist positive tests', async () => {
      await this.unic.addToBlacklist(holder, { from: owner });
      expect(await this.unic.isBlacklisted(holder)).to.equal(true);
      await this.unic.rempoveFromBlacklist(holder, { from: owner });
      expect(await this.unic.isBlacklisted(holder)).to.equal(false);
    });

    it('blacklist negative tests', async () => {
      await this.unic.addToBlacklist(holder, { from: owner });
      await expectRevert(this.unic.addToBlacklist(holder, { from: owner }), 'In black list');
      await this.unic.rempoveFromBlacklist(holder, { from: owner });
      await expectRevert(this.unic.rempoveFromBlacklist(holder, { from: owner }), 'Not blacklisted');
      await expectRevert.unspecified(this.unic.rempoveFromBlacklist(burner, { from: holder }));
    });
  });
});
