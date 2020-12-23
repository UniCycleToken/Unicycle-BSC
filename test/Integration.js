const {
  BN, ether, time, expectRevert,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const UNICToken = artifacts.require('UNICToken');
const Auction = artifacts.require('Auction');

contract('AUCTION test', async ([owner, alice, bob]) => {
  beforeEach(async () => {
    const startTime = await time.latest();
    this.unic = await UNICToken.new({ from: owner });
    this.auction = await Auction.new(this.unic.address, startTime, owner, { from: owner });
    await this.unic.setAuction(this.auction.address, { from: owner });
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
  });

  it('check participate and unlock after n day pause', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400 * 2,
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 2, { from: alice })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 2, { from: bob })).to.be.bignumber.equal(ether('0'));
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('2'));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 3,
    await this.auction.participate({ from: bob, value: ether('2') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('3'));
    expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 2, { from: alice })).to.be.bignumber.equal(ether('2500000'));
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 3, { from: bob })).to.be.bignumber.equal(ether('2500000'));
    // 3 and 4 days pause
    await time.increase(time.duration.days(1)); // startTime + 86400 * 4,
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('4'));
    await time.increase(time.duration.days(1)); // startTime + 86400 * 5,
    await this.auction.participate({ from: bob, value: ether('2') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('5'));
    expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('2'));
    expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('4'));
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 4, { from: alice })).to.be.bignumber.equal(ether('2500000'));
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 5, { from: bob })).to.be.bignumber.equal(ether('2500000'));
    // 5 days pause
    await time.increase(time.duration.days(1)); // startTime + 86400 * 6,
    await this.auction.participate({ from: alice, value: ether('1') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), alice, { from: alice })).to.be.bignumber.equal(ether('1'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
    await this.auction.participate({ from: bob, value: ether('4') });
    expect(await this.auction.getParticipatedETHAmount(await this.auction.getLastMintTime(), bob, { from: bob })).to.be.bignumber.equal(ether('4'));
    expect(await this.auction.getMintTimesLength()).to.be.bignumber.equal(new BN('6'));
    expect(await this.auction.getTotalParticipateAmount({ from: alice })).to.be.bignumber.equal(ether('3'));
    expect(await this.auction.getTotalParticipateAmount({ from: bob })).to.be.bignumber.equal(ether('8'));
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 6, { from: alice })).to.be.bignumber.equal(ether('500000'));
    expect(await this.auction.canUnlockTokens(startTime + 86400 * 6, { from: bob })).to.be.bignumber.equal(ether('2000000'));
    // a lot of tokens, cause no one unlocked yet
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('12500000'));
    // await time.advanceBlock();
    // now unlock them one by one
    // (await this.auction.canUnlockTokens(startTime + 86400 * 2, { from: alice }));
    await time.increase(time.duration.days(4)); // startTime + 86400 * 10,
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
    // alice was the only one participating that day she took all unics for the day
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('2500000'));
    await this.auction.unlockTokens(startTime + 86400 * 3, { from: bob });
    // bob was the only one participating that day he took all unics for the day
    expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('2500000'));
    // the balance of auction was subbed accordingly
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('7500000'));
    // unlock the tokens from the last day when bob and alice participate together
    await this.auction.unlockTokens(startTime + 86400 * 6, { from: alice });
    await this.auction.unlockTokens(startTime + 86400 * 6, { from: bob });
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('3000000'));
    expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('4500000'));
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('5000000'));
  });

  it('Check stake and unstake for n days', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400,
    await this.auction.participate({ from: owner, value: ether('1') });
    await this.auction.participate({ from: alice, value: ether('1') });
    await this.auction.participate({ from: bob, value: ether('3') });
    await time.increase(time.duration.days(1)); // startTime + 86400,
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: owner });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: bob });
    expect(await this.unic.balanceOf(owner)).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(bob)).to.be.bignumber.equal(ether('1500000'));
    await this.unic.approve(this.auction.address, ether('500000'), { from: owner });
    await this.unic.approve(this.auction.address, ether('500000'), { from: alice });
    await this.unic.approve(this.auction.address, ether('1500000'), { from: bob });
    await expectRevert(this.auction.unStake(startTime + 86400, { from: owner }), 'Nothing to unstake');
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('0'));
    expect(await this.auction.getAccumulativeUnic()).to.be.bignumber.equal(ether('0'));
    await this.auction.stake(ether('500000'), { from: owner });
    expect(await this.auction.getAccumulativeUnic()).to.be.bignumber.equal(ether('500000'));
    await this.auction.stake(ether('500000'), { from: alice });
    expect(await this.auction.getAccumulativeUnic()).to.be.bignumber.equal(ether('1000000'));
    expect(await this.auction.getStakedUnic(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('50000'));
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('12550000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('30'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('11.875'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('11.875'));
    await this.auction.stake(ether('1500000'), { from: bob });
    expect(await this.auction.getAccumulativeUnic()).to.be.bignumber.equal(ether('2500000'));
    for (let i = 0; i < 5; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('5') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25125000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('55'));
    expect(await this.auction.getStakedUnic(startTime + 86400 * 3, owner, { from: owner })).to.be.bignumber.equal(ether('500000'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: owner })).to.be.bignumber.equal(ether('16.625'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('16.625'));
    expect(await this.auction.canUnStake(startTime + 86400 * 8, { from: bob })).to.be.bignumber.equal(ether('14.25'));
    await this.auction.unStake(startTime + 86400 * 3, { from: owner });
    await this.auction.unStake(startTime + 86400 * 3, { from: alice });
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('21.75'));
    await this.auction.unStake(startTime + 86400 * 8, { from: bob });
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('7.5'));
    // doesnt include 95% of staked eth on first day = 4.75
    expect(await this.auction.getTeamETHShare({ from: owner })).to.be.bignumber.equal(ether('2.75'));
    await this.auction.takeTeamETHShare({ from: owner });
    await this.auction.takeTeamETHShare({ from: owner });
    expect(await this.auction.getTeamETHShare({ from: owner })).to.be.bignumber.equal(ether('0'));
  });

  it('check unStake after 100 days', async () => {
    const startTime = (await this.auction.getLastMintTime()).toNumber();
    await time.increase(time.duration.days(2)); // startTime + 86400,
    await this.auction.participate({ from: alice, value: ether('1') });
    await time.increase(time.duration.days(1)); // startTime + 86400,
    await this.auction.unlockTokens(startTime + 86400 * 2, { from: alice });
    expect(await this.unic.balanceOf(alice)).to.be.bignumber.equal(ether('2500000'));
    await this.unic.approve(this.auction.address, ether('500000'), { from: alice });
    await this.auction.stake(ether('500000'), { from: alice });
    expect(await this.auction.getAccumulativeUnic()).to.be.bignumber.equal(ether('500000'));
    expect(await this.auction.getStakedUnic(startTime + 86400 * 3, alice, { from: alice })).to.be.bignumber.equal(ether('500000'));
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('25000'));
    for (let i = 0; i < 110; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await this.auction.participate({ from: owner, value: ether('0.1') });
      // eslint-disable-next-line no-await-in-loop
      await time.increase(time.duration.days(1));
    }
    expect(await this.unic.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('275025000'));
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('12'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('9.5'));
    await this.auction.unStake(startTime + 86400 * 3, { from: alice });
    expect(await web3.eth.getBalance(this.auction.address)).to.be.bignumber.equal(ether('2.5'));
    expect(await this.auction.canUnStake(startTime + 86400 * 3, { from: alice })).to.be.bignumber.equal(ether('0'));
  });
});
