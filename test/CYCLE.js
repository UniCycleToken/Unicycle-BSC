const {
  BN,
  ether,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const CYCLEToken = artifacts.require('CYCLEToken');
const Auction = artifacts.require('Auction');

contract('CYCLE test', async ([owner, burner, holder]) => {
  const startTime = Math.floor(Date.now() / 1000) - 86400;
  const zeroAddress = '0x0000000000000000000000000000000000000000';

  beforeEach(async () => {
    this.cycle = await CYCLEToken.new({ from: owner });
    this.auction = await Auction.new(this.cycle.address, startTime, owner, { from: owner });
    await this.cycle.setAuction(this.auction.address, { from: owner });
  });

  it('setAuction and mint should fail', async () => {
    await expectRevert(this.cycle.setAuction(zeroAddress, { from: owner }), 'Zero address');
    await expectRevert(this.cycle.mint(100, { from: owner }), 'Caller is not auction');
  });

  it('checking the cycle token parameters', async () => {
    expect(await this.cycle.name.call()).to.equal('CYCLEToken');
    expect(await this.cycle.symbol.call()).to.equal('CYCLE');
    expect(await this.cycle.decimals.call()).to.be.bignumber.equal(new BN('18'));
    expect(await this.cycle.totalSupply.call()).to.be.bignumber.equal(new BN('0'));
  });

  it('check startAuction => setStartTime and mint', async () => {
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('0'));
    await this.auction.participate({ from: owner, value: 100000 });
    expect(await this.cycle.balanceOf(this.auction.address)).to.be.bignumber.equal(ether('100000'));
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
