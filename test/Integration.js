const {
  BN, ether, time, expectRevert,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const { cycle } = require('./Utils');

const CYCLEToken = artifacts.require('CYCLEToken');
const Auction = artifacts.require('Auction');
const WETH = artifacts.require('WETH9');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');
const UniswapV2Pair = artifacts.require('UniswapV2Pair');

contract('Integration test', async ([owner, alice, bob]) => {
  beforeEach(async () => {
    const startTime = await time.latest();
    this.cycle = await CYCLEToken.new({ from: owner });
    this.weth = await WETH.new({ from: owner });
    this.factory = await UniswapV2Factory.new(owner, { from: owner });
    this.team = web3.eth.accounts.create();
    this.router = await UniswapV2Router02.new(this.factory.address, this.weth.address, { from: owner });
    this.auction = await Auction.new(this.cycle.address, this.router.address, startTime, this.team.address, { from: owner });
    await this.cycle.setAuction(this.auction.address, { from: owner });
    const pair = await this.factory.getPair(this.weth.address, this.cycle.address);
    await this.cycle.setCYCLEWETHAddress(pair, { from: owner });
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('0'));
  });

  it('check participate and unlock after n day pause', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400 * 2,
    expect(await this.auction.canTakeShare(startTime + 86400 * 2, alice, { from: alice })).to.be.bignumber.equal(cycle('0'));
    expect(await this.auction.canTakeShare(startTime + 86400 * 2, bob, { from: bob })).to.be.bignumber.equal(cycle('0'));
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('2'));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 3,
    await this.auction.participate({ from: bob, value: ether('2') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('3'));
    expect(await this.auction.getTotalParticipateAmount(alice, { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getTotalParticipateAmount(bob, { from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.canTakeShare(startTime + 86400 * 2, alice, { from: alice })).to.be.bignumber.equal(cycle('100000'));
    expect(await this.auction.canTakeShare(startTime + 86400 * 3, bob, { from: bob })).to.be.bignumber.equal(cycle('100000'));
    // 3 and 4 days pause
    await time.increase(time.duration.days(1)); // startTime + 86400 * 4,
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('4'));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 5,
    await this.auction.participate({ from: bob, value: ether('2') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('5'));
    expect(await this.auction.getTotalParticipateAmount(alice, { from: alice })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getTotalParticipateAmount(bob, { from: bob })).to.be.bignumber.equal(ether('4'));
    expect(await this.auction.canTakeShare(startTime + 86400 * 4, alice, { from: alice })).to.be.bignumber.equal(cycle('100000'));
    expect(await this.auction.canTakeShare(startTime + 86400 * 5, bob, { from: bob })).to.be.bignumber.equal(cycle('100000'));
    // 5 days pause
    await time.increase(time.duration.days(1)); // startTime + 86400 * 6,
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
    await this.auction.participate({ from: bob, value: ether('4') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('4'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
    expect(await this.auction.getTotalParticipateAmount(alice, { from: alice })).to.be.bignumber.equal(ether('3'));
    expect(await this.auction.getTotalParticipateAmount(bob, { from: bob })).to.be.bignumber.equal(ether('8'));
    expect(await this.auction.canTakeShare(startTime + 86400 * 6, alice, { from: alice })).to.be.bignumber.equal(cycle('20000'));
    expect(await this.auction.canTakeShare(startTime + 86400 * 6, bob, { from: bob })).to.be.bignumber.equal(cycle('80000'));
    // a lot of tokens, cause no one unlocked yet
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('500000'));
    // await time.advanceBlock();
    // now unlock them one by one
    // (await this.auction.canTakeShare(startTime + 86400 * 2, { from: alice }));
    await time.increase(time.duration.days(4)); // startTime + 86400 * 10,
    await this.auction.takeShare(startTime + 86400 * 2, alice, { from: alice });
    // alice was the only one participating that day she took all cycles for the day
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('100000'));
    await this.auction.takeShare(startTime + 86400 * 3, bob, { from: bob });
    // bob was the only one participating that day he took all cycles for the day
    expect(await this.cycle.balanceOf(bob)).to.be.bignumber.equal(cycle('100000'));
    // the balance of auction was subbed accordingly
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('300000'));
    // unlock the tokens from the last day when bob and alice participate together
    await this.auction.takeShare(startTime + 86400 * 6, alice, { from: alice });
    await this.auction.takeShare(startTime + 86400 * 6, bob, { from: bob });
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('120000'));
    expect(await this.cycle.balanceOf(bob)).to.be.bignumber.equal(cycle('180000'));
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('200000'));
  });

  it('Check stake and unstake for n days', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400,
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.auction.participate({ from: alice, value: ether('1') });
    await this.auction.participate({ from: bob, value: ether('3') });
    await time.increase(time.duration.days(1)); // startTime + 86400,
    await this.auction.takeShare(startTime + 86400 * 2, owner, { from: owner });
    await this.auction.takeShare(startTime + 86400 * 2, alice, { from: alice });
    await this.auction.takeShare(startTime + 86400 * 2, bob, { from: bob });
    expect(await this.cycle.balanceOf(owner)).to.be.bignumber.equal(cycle('20000'));
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('20000'));
    expect(await this.cycle.balanceOf(bob)).to.be.bignumber.equal(cycle('60000'));
    await this.cycle.approve(this.auction.address, cycle('20000'), { from: owner });
    await this.cycle.approve(this.auction.address, cycle('20000'), { from: alice });
    await this.cycle.approve(this.auction.address, cycle('60000'), { from: bob });
    await expectRevert(this.auction.unstake(startTime + 86400, owner, { from: owner }), 'Nothing to unstake');
    expect(await this.auction.canUnstake(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnstake(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.getAccumulativeCycle()).to.be.bignumber.equal(ether('0'));
    await this.auction.stake(cycle('20000'), { from: owner });
    expect(await this.auction.getAccumulativeCycle()).to.be.bignumber.equal(cycle('20000'));
    await this.auction.stake(cycle('20000'), { from: alice });
    expect(await this.auction.getAccumulativeCycle()).to.be.bignumber.equal(cycle('40000'));
    expect(await this.auction.getStakedCycle(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(cycle('20000'));
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('2000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('5'));
    for (let i = 0; i < 5; ++i) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await web3.eth.getBalance(this.team.address)).to.be.bignumber.equal(ether('3.5'));
    const pairAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
    
    const pair = await UniswapV2Pair.at(pairAddress);
    expect(await this.weth.balanceOf(pairAddress)).to.be.bignumber.equal(ether('2.5'));

    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('502000'));
    // (4 days * (20 - 5%)) + 1 last day with 5%
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('24'));
    // 23.75 = 11.875 * 2
    expect(await this.auction.canUnstake(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('11.875'));
    expect(await this.auction.canUnstake(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('11.875'));
    await this.auction.stake(cycle('60000'), { from: bob });
    expect(await this.auction.getAccumulativeCycle()).to.be.bignumber.equal(cycle('100000'));
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('1005000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('47.75'));
    expect(await this.auction.getStakedCycle(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(cycle('20000'));
    expect(await this.auction.canUnstake(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('16.625'));
    expect(await this.auction.canUnstake(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('16.625'));
    expect(await this.auction.canUnstake(startTime + 86400 * 8, bob, { from: bob })).to.be.bignumber.equal(ether('14.25'));

    await this.auction.unstake(startTime + 86400 * 3, owner, { from: owner });
    expect(await this.auction.canUnstake(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnstake(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('16.625'));
    expect(await this.auction.canUnstake(startTime + 86400 * 8, bob, { from: bob })).to.be.bignumber.equal(ether('14.25'));
    // expect(ether('16.625')).to.be.bignumber.equal((new BN(await web3.eth.getBalance(owner))).sub(ownerBalance));
    await this.auction.unstake(startTime + 86400 * 3, alice, { from: alice });
    // expect(await web3.eth.getBalance(alice)).to.be.bignumber.equal(ether('16.625'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('14.5'));
    await this.auction.unstake(startTime + 86400 * 8, bob, { from: bob });
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('0.25'));

    expect((await this.auction.getTeamInfo({ from: owner }))[0]).to.be.bignumber.equal(ether('0.25'));
    expect(await web3.eth.getBalance(this.team.address)).to.be.bignumber.equal(ether('4.75'));

    // const pairAddress = await this.factory.getPair(this.weth.address, this.cycle.address);
    expect(await this.cycle.balanceOf(pairAddress)).to.be.bignumber.equal(cycle('50000'));
    expect(await this.weth.balanceOf(pairAddress)).to.be.bignumber.equal(ether('2.5'));
  });

  it('check unstake after 100 days', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400,
    await this.auction.participate({ from: alice, value: ether('1') });
    await time.increase(time.duration.days(1)); // startTime + 86400,
    await this.auction.takeShare(startTime + 86400 * 2, alice, { from: alice });
    expect(await this.cycle.balanceOf(alice)).to.be.bignumber.equal(cycle('100000'));
    await this.cycle.approve(this.auction.address, cycle('20000'), { from: alice });
    await this.auction.stake(cycle('20000'), { from: alice });
    expect(await this.auction.getAccumulativeCycle()).to.be.bignumber.equal(cycle('20000'));
    expect(await this.auction.getStakedCycle(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(cycle('20000'));
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('1000'));
    for (let i = 0; i < 110; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('0.1') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(cycle('11001000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('10.455'));
    expect(await this.auction.canUnstake(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('9.5'));
    await this.auction.unstake(startTime + 86400 * 3, alice, { from: alice });
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('0.955'));
    expect(await this.auction.canUnstake(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('0'));
  });
  
  it('check userStakeTimes mapping updating correctly', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    // prepare for staking
    await time.increase(time.duration.days(2)); // startTime + 86400 * 2,
    await this.auction.participate({ from: owner, value: ether('1') });
    await time.increase(time.duration.days(1)); // startTime + 86400 * 3,
    await this.auction.takeShare(startTime + 86400 * 2, owner, { from: owner });
    await this.cycle.approve(this.auction.address, cycle('20000'), { from: owner });
    expect((await this.auction.getUserStakesData(owner, { from: owner })).length).to.equal(0);
    // checking adding to mapping
    await this.auction.stake(cycle('4000'), { from: owner });
    expect((await this.auction.getUserStakesData(owner, { from: owner })).length).to.equal(1);
    expect((await this.auction.getUserStakesData(owner, { from: owner }))[0]).to.be.bignumber.equal(new BN((startTime + 86400 * 3).toString()));
    await this.auction.stake(cycle('4000'), { from: owner });
    expect((await this.auction.getUserStakesData(owner, { from: owner })).length).equal(1);
    expect((await this.auction.getUserStakesData(owner, { from: owner }))[0]).to.be.bignumber.equal(new BN((startTime + 86400 * 3).toString()));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 4,
    await this.auction.stake(cycle('4000'), { from: owner });
    expect((await this.auction.getUserStakesData(owner, { from: owner })).length).to.equal(2);
    expect((await this.auction.getUserStakesData(owner, { from: owner }))[1]).to.be.bignumber.equal(new BN((startTime + 86400 * 4).toString()));
    await this.auction.stake(cycle('2000'), { from: owner });
    expect((await this.auction.getUserStakesData(owner, { from: owner })).length).to.equal(2);
    expect((await this.auction.getUserStakesData(owner, { from: owner }))[0]).to.be.bignumber.equal(new BN((startTime + 86400 * 3).toString()));
    expect((await this.auction.getUserStakesData(owner, { from: owner }))[1]).to.be.bignumber.equal(new BN((startTime + 86400 * 4).toString()));
    for (let i = 0; i < 100; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
      // eslint-disable-next-line no-await-in-loop
      await this.auction.stake(cycle('50'), { from: owner });
    }
    expect((await this.auction.getUserStakesData(owner, { from: owner })).length).to.equal(102);
    expect((await this.auction.getUserStakesData(owner, { from: owner }))[101]).to.be.bignumber.equal(new BN((startTime + 86400 * 104).toString()));
    // checking deleting from mapping
    await this.auction.unstake(startTime + 86400 * 4, owner, { from: owner });
    expect((await this.auction.getUserStakesData(owner, { from: owner })).length).to.equal(101);
    expect((await this.auction.getUserStakesData(owner, { from: owner }))[1]).to.be.bignumber.equal(new BN((startTime + 86400 * 104).toString()));
  });

  it('check userParticipateTimes mapping updating correctly', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    // prepare for staking
    // checking adding to mapping
    expect((await this.auction.getUserParticipatesData(owner, { from: owner })).length).to.equal(0);
    await this.auction.participate({ from: owner, value: ether('1') });
    expect((await this.auction.getUserParticipatesData(owner, { from: owner })).length).to.equal(1);
    expect((await this.auction.getUserParticipatesData(owner, { from: owner }))[0]).to.be.bignumber.equal(new BN((startTime).toString()));
    await this.auction.participate({ from: owner, value: ether('1') });
    expect((await this.auction.getUserParticipatesData(owner, { from: owner })).length).to.equal(1);
    await time.increase(time.duration.days(1));
    expect((await this.auction.getUserParticipatesData(owner, { from: owner })).length).to.equal(1);
    await this.auction.participate({ from: owner, value: ether('1') });
    expect((await this.auction.getUserParticipatesData(owner, { from: owner })).length).to.equal(2);
    expect((await this.auction.getUserParticipatesData(owner, { from: owner }))[1]).to.be.bignumber.equal(new BN((startTime + 86400).toString()));
    for (let i = 0; i < 10; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('1') });
    }
    expect((await this.auction.getUserParticipatesData(owner, { from: owner })).length).to.equal(12);
    expect((await this.auction.getUserParticipatesData(owner, { from: owner }))[11]).to.be.bignumber.equal(new BN((startTime + 86400 * 11).toString()));
    await this.auction.takeShare(startTime, owner, { from: owner });
    expect((await this.auction.getUserParticipatesData(owner, { from: owner }))[0]).to.be.bignumber.equal(new BN((startTime + 86400 * 11).toString()));
  });
});
