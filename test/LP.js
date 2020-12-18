const {
  expectRevert,
  ether,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('FakeAuction');
const WETH = artifacts.require('WETH9');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('LP related test', async ([owner, alice, bob]) => {
  const startTime = Math.floor(Date.now() / 1000) - 86400 * 20;

  beforeEach(async () => {
    this.unic = await UNICToken.new({ from: owner });
    this.weth = await WETH.new({ from: owner });
    this.factory = await UniswapV2Factory.new(owner, { from: owner });
    await this.factory.createPair(this.weth.address, this.unic.address);
    this.auction = await Auction.new(this.unic.address, startTime, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
    this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });

    // prepare LPStake for owner
    await this.auction.participate(startTime + 86400 * 2, { from: owner, value: ether('1') });
    await this.weth.deposit({ from: owner, value: ether('30') });
    await this.unic.approve(this.router.address, ether('30'), { from: owner });
    await this.weth.approve(this.router.address, ether('30'), { from: owner });
    // prepare LPStake for alice
    await this.auction.participate(startTime + 86400 * 2, { from: alice, value: ether('1') });
    await this.weth.deposit({ from: alice, value: ether('30') });
    await this.unic.approve(this.router.address, ether('30'), { from: alice });
    await this.weth.approve(this.router.address, ether('30'), { from: alice });

    await this.auction.unlockTokens(startTime + 86400 * 2, { from: owner });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('1250000'));
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('1250000'));
  });

  it('check that remove liquidity is blocked', async () => {
    const blocktime = (await web3.eth.getBlock()).timestamp;
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blocktime + 30, { from: owner });
    const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
    this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
    await this.lpToken.approve(this.router.address, ether('10'), { from: owner });
    await this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blocktime + 60, { from: owner });
    expect(await this.unic.isBlacklisted(lpTokenAddress)).to.equal(false);
    await this.unic.addToBlacklist(lpTokenAddress);
    expect(await this.unic.isBlacklisted(lpTokenAddress)).to.equal(true);
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blocktime + 90, { from: owner });
    await expectRevert(this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blocktime + 120, { from: owner }), 'UniswapV2: TRANSFER_FAILED');
    await this.unic.rempoveFromBlacklist(lpTokenAddress);
    await this.router.removeLiquidity(this.weth.address, this.unic.address, ether('1'), 0, 0, owner, blocktime + 60, { from: owner });
  });

  it('check LPStake reward payout', async () => {
    const blocktime = (await web3.eth.getBlock()).timestamp;
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, owner, blocktime + 30, { from: owner });
    await this.router.addLiquidity(this.weth.address, this.unic.address, ether('10'), ether('10'), 0, 0, alice, blocktime + 30, { from: alice });
    const lpTokenAddress = await this.factory.getPair(this.weth.address, this.unic.address);
    this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
    await this.lpToken.approve(this.auction.address, ether('10'), { from: owner });
    await this.lpToken.approve(this.auction.address, ether('10'), { from: alice });
    await this.unic.addToBlacklist(lpTokenAddress);
    await this.auction.stakeLP(lpTokenAddress, ether('0.5'), startTime + 86400 * 3, { from: owner });
    expect(await this.auction.getDailyTotalStakedLP(startTime + 86400 * 3)).to.be.bignumber.equal(ether('0.5'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('0.5'));
    await this.auction.stakeLP(lpTokenAddress, ether('0.5'), startTime + 86400 * 3, { from: owner });
    expect(await this.auction.getDailyTotalStakedLP(startTime + 86400 * 3)).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('1'));
    await this.auction.stakeLP(lpTokenAddress, ether('4'), startTime + 86400 * 3, { from: alice });
    expect(await this.auction.getDailyTotalStakedLP(startTime + 86400 * 3)).to.be.bignumber.equal(ether('5'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('4'));
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
    for (let i = 4; i < 14; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate(startTime + 86400 * i, { from: bob, value: ether('5') });
    }
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25000000'));
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('1249990'));
    await this.auction.unlockLPReward(startTime + 86400 * 3, startTime + 86400 * 20, { from: owner });
    // + 2 500 000 * 10 / 20 = 1 250 000, owners share is 20% => 250 000
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('1499990'));
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('1249990'));
    await this.auction.unlockLPReward(startTime + 86400 * 3, startTime + 86400 * 20, { from: alice });
    // + 2 500 000 * 10 / 20 = 1 250 000, owners share is 20% => 250 000
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('2249990'));
  });
});
