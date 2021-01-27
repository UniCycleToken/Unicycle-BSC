const {
  expectRevert, ether, time, BN,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const { cycle } = require('./Utils');

const CYCLEToken = artifacts.require('CYCLEToken');
const Auction = artifacts.require('Auction');
const WETH = artifacts.require('WETH9');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('LP related test', async ([owner, alice, bob]) => {
  beforeEach(async () => {
    const startTime = await time.latest();
    this.cycle = await CYCLEToken.new({ from: owner });
    this.weth = await WETH.new({ from: owner });
    this.factory = await UniswapV2Factory.new(owner, { from: owner });
    await this.factory.createPair(this.weth.address, this.cycle.address);
    this.team = web3.eth.accounts.create();
    this.auction = await Auction.new(this.cycle.address, this.factory.address, this.weth.address, startTime, this.team.address, { from: owner });
    await this.cycle.setAuction(this.auction.address, { from: owner });
    this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });
  });

  it('check that remove liquidity is blocked', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2));
    // prepare LPStake for owner
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.weth.deposit({ from: owner, value: ether('30') });
    await this.cycle.approve(this.router.address, ether('30'), { from: owner });
    await this.weth.approve(this.router.address, ether('30'), { from: owner });
    // prepare LPStake for alice
    await this.auction.participate({ from: alice, value: ether('1') });
    await this.weth.deposit({ from: alice, value: ether('30') });
    await this.cycle.approve(this.router.address, ether('30'), { from: alice });
    await this.weth.approve(this.router.address, ether('30'), { from: alice });
    await time.increase(time.duration.days(1));
    await this.auction.takeShare(startTime + 86400 * 2, owner, { from: owner });
    await this.auction.takeShare(startTime + 86400 * 2, alice, { from: alice });
    expect(await this.cycle.balanceOf(owner)).to.be.bignumber.equal(cycle('50000'));
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('50000'));
    const blockTime = await time.latest();
    await this.router.addLiquidity(this.weth.address, this.cycle.address, ether('10'), cycle('10'), 0, 0, owner, blockTime + 30, { from: owner });
    const lpTokenAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
    this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
    await this.lpToken.approve(this.router.address, ether('10'), { from: owner });
    await this.router.removeLiquidity(this.weth.address, this.cycle.address, ether('1'), 0, 0, owner, blockTime + 60, { from: owner });
    expect(await this.cycle.isBlacklisted(lpTokenAddress)).to.equal(false);
    await this.cycle.addToBlacklist(lpTokenAddress);
    expect(await this.cycle.isBlacklisted(lpTokenAddress)).to.equal(true);
    await this.router.addLiquidity(this.weth.address, this.cycle.address, ether('10'), cycle('10'), 0, 0, owner, blockTime + 90, { from: owner });
    await expectRevert(this.router.removeLiquidity(this.weth.address, this.cycle.address, ether('1'), 0, 0, owner, blockTime + 120, { from: owner }), 'UniswapV2: TRANSFER_FAILED');
    await this.cycle.removeFromBlacklist(lpTokenAddress);
    await this.router.removeLiquidity(this.weth.address, this.cycle.address, ether('1'), 0, 0, owner, blockTime + 150, { from: owner });
  });

  it('check LPStake reward payout', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2));
    // prepare LPStake for owner
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.weth.deposit({ from: owner, value: ether('30') });
    await this.cycle.approve(this.router.address, cycle('30'), { from: owner });
    await this.weth.approve(this.router.address, ether('30'), { from: owner });
    // prepare LPStake for alice
    await this.auction.participate({ from: alice, value: ether('1') });
    await this.weth.deposit({ from: alice, value: ether('30') });
    await this.cycle.approve(this.router.address, cycle('30'), { from: alice });
    await this.weth.approve(this.router.address, ether('30'), { from: alice });
    // prepare LPStake for Bob
    await this.auction.participate({ from: bob, value: ether('3') });
    await this.weth.deposit({ from: bob, value: ether('30') });
    await this.cycle.approve(this.router.address, cycle('30'), { from: bob });
    await this.weth.approve(this.router.address, ether('30'), { from: bob });
    await time.increase(time.duration.days(1));
    await this.auction.takeShare(startTime + 86400 * 2, owner, { from: owner });
    await this.auction.takeShare(startTime + 86400 * 2, alice, { from: alice });
    await this.auction.takeShare(startTime + 86400 * 2, bob, { from: bob });
    expect(await this.cycle.balanceOf(owner)).to.be.bignumber.equal(cycle('20000'));
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('20000'));
    expect(await this.cycle.balanceOf(bob)).to.be.bignumber.equal(cycle('60000'));

    const blockTime = await time.latest();
    await this.router.addLiquidity(this.weth.address, this.cycle.address, ether('10'), cycle('10'), 0, 0, owner, blockTime + 30, { from: owner });
    await this.router.addLiquidity(this.weth.address, this.cycle.address, ether('10'), cycle('10'), 0, 0, alice, blockTime + 30, { from: alice });
    await this.router.addLiquidity(this.weth.address, this.cycle.address, ether('10'), cycle('10'), 0, 0, bob, blockTime + 30, { from: bob });
    const lpTokenAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
    this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
    await this.lpToken.approve(this.auction.address, ether('10'), { from: owner });
    await this.lpToken.approve(this.auction.address, ether('10'), { from: alice });
    await this.lpToken.approve(this.auction.address, ether('10'), { from: bob });
    await this.cycle.addToBlacklist(lpTokenAddress);
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('0'));
    await expectRevert(this.auction.stakeLP(lpTokenAddress, ether('0'), { from: owner }), 'Invalid stake amount');
    await expectRevert(this.auction.stakeLP(alice, ether('0'), { from: owner }), 'Token is not supported');
    await this.auction.stakeLP(lpTokenAddress, ether('0.5'), { from: owner });
    expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('0.5'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('0.5'));
    await this.auction.stakeLP(lpTokenAddress, ether('0.5'), { from: owner });
    expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('1'));
    await this.auction.stakeLP(lpTokenAddress, ether('4'), { from: alice });
    expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('5'));
    expect(await this.auction.getStakedLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('4'));
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
    for (let i = 0; i < 10; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: bob, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('1000000'));
    expect(await this.cycle.balanceOf(owner)).to.be.bignumber.equal(cycle('19990'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('10000'));
    expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(new BN(startTime + 86400 * 3));
    await expectRevert(this.auction.unstakeLP(startTime + 86400 * 2, owner, { from: owner }), 'Nothing to unlock');
    await this.auction.unstakeLP(startTime + 86400 * 3, owner, { from: owner });
    expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3,owner, { from: owner })).to.be.bignumber.equal(new BN(startTime + 86400 * 13));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('0'));
    // + 100 000 * 10 / 20 = 50 000, owners share is 20% => 10 000
    expect(await this.cycle.balanceOf(owner)).to.be.bignumber.equal(ether('29990'));
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(ether('19990'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('40000'));
    
    await this.auction.unstakeLP(startTime + 86400 * 3, alice, { from: alice });
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('0'));
    // + 100 000 * 10 / 20 = 50 000, alice share is 80% => 40 000
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(ether('59990'));

    // add another LP staker in the middle of new participation cycle
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: alice, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('5000'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('20000'));
    await this.auction.stakeLP(lpTokenAddress, ether('5'), { from: bob });
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('7500'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('30000'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 18, bob, { from: bob })).to.be.bignumber.equal(ether('12500'));
    await this.auction.unstakeLP(startTime + 86400 * 3, owner, { from: owner });
    expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(new BN(startTime + 86400 * 23));
    await this.auction.unstakeLP(startTime + 86400 * 3, alice, { from: alice });
    await this.auction.unstakeLP(startTime + 86400 * 18, bob, { from: bob });
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnstakeLP(startTime + 86400 * 18, bob, { from: bob })).to.be.bignumber.equal(ether('0'));
  });

  it('checking that userLPStakes is updating correctly', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400 * 2
    // prepare LPStake for owner
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.weth.deposit({ from: owner, value: ether('5') });
    await this.cycle.approve(this.router.address, ether('5'), { from: owner });
    await this.weth.approve(this.router.address, ether('5'), { from: owner });
    await time.increase(time.duration.days(1)); // startTime + 86400 * 3
    await this.auction.takeShare(startTime + 86400 * 2, owner, { from: owner });
    const blockTime = await time.latest();
    await this.router.addLiquidity(this.weth.address, this.cycle.address, ether('5'), ether('5'), 0, 0, owner, blockTime + 30, { from: owner });
    const lpTokenAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
    this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
    await this.lpToken.approve(this.auction.address, ether('5'), { from: owner });
    await this.cycle.addToBlacklist(lpTokenAddress);
    expect((await this.auction.getUserLPStakesData(owner, { from: owner })).length).to.equal(0);
    await this.auction.stakeLP(lpTokenAddress, ether('0.1'), { from: owner });
    expect((await this.auction.getUserLPStakesData(owner, { from: owner })).length).to.equal(1);
    expect((await this.auction.getUserLPStakesData(owner, { from: owner }))[0]).to.be.bignumber.equal(new BN((startTime + 86400 * 3).toString()));
    await this.auction.stakeLP(lpTokenAddress, ether('0.1'), { from: owner });
    expect((await this.auction.getUserLPStakesData(owner, { from: owner })).length).to.equal(1);
    expect((await this.auction.getUserLPStakesData(owner, { from: owner }))[0]).to.be.bignumber.equal(new BN((startTime + 86400 * 3).toString()));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 4
    await this.auction.stakeLP(lpTokenAddress, ether('0.1'), { from: owner });
    expect((await this.auction.getUserLPStakesData(owner, { from: owner })).length).to.equal(2);
    expect((await this.auction.getUserLPStakesData(owner, { from: owner }))[1]).to.be.bignumber.equal(new BN((startTime + 86400 * 4).toString()));

    for (let i = 0; i < 10; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
      // eslint-disable-next-line no-await-in-loop
      await this.auction.stakeLP(lpTokenAddress, ether('0.1'), { from: owner });
    }
    expect((await this.auction.getUserLPStakesData(owner, { from: owner })).length).to.equal(12);
    expect((await this.auction.getUserLPStakesData(owner, { from: owner }))[11]).to.be.bignumber.equal(new BN((startTime + 86400 * 14).toString()));
  });
  // takes 6-10mins
  // it('check LP stake for 1000 days breakpoint', async () => {
  //   const startTime = (await this.auction.getLastMintTime()).toNumber();
  //   await time.increase(time.duration.days(2));
  //   // prepare LPStake for alice
  //   await this.auction.participate({ from: alice, value: ether('1') });
  //   await this.weth.deposit({ from: alice, value: ether('10') });
  //   await this.cycle.approve(this.router.address, ether('10'), { from: alice });
  //   await this.weth.approve(this.router.address, ether('10'), { from: alice });
  //   await time.increase(time.duration.days(1));
  //   await this.auction.takeShare(startTime + 86400 * 2, alice, { from: alice });
  //   expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(ether('2500000'));

  //   const blockTime = await time.latest();
  //   await this.router.addLiquidity(this.weth.address, this.cycle.address, ether('10'), ether('10'), 0, 0, alice, blockTime + 30, { from: alice });
  //   const lpTokenAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
  //   this.lpToken = await UniswapV2Pair.at(lpTokenAddress);
  //   await this.lpToken.approve(this.auction.address, ether('10'), { from: alice });
  //   await this.cycle.addToBlacklist(lpTokenAddress);
  //   await this.auction.stakeLP(lpTokenAddress, ether('1'), { from: alice });
  //   expect(await this.auction.getAccumulativeLP()).to.be.bignumber.equal(ether('1'));
  //   expect(await this.auction.getStakedLP(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('1'));
  //   expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
  //   for (let i = 0; i < 1100; i += 1) {
  //     // eslint-disable-next-line no-await-in-loop
  //     await this.auction.participate({ from: bob, value: ether('0.01') });
  //     // eslint-disable-next-line no-await-in-loop
  //     await time.increase(time.duration.days(1));
  //   }
  //   expect(await this.auction.canUnstakeLP(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('137500000'));
  //   expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(new BN(startTime + 86400 * 3));
  //   await this.auction.unstakeLP(startTime + 86400 * 3, { from: alice });
  //   expect(await this.auction.getLastLpUnlockTime(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(new BN(startTime + 86400 * 1103));
  // });
});
