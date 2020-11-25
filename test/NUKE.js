/* eslint-disable */
const {
  BN,
  expectRevert,
} = require('openzeppelin-test-helpers');
const { expect } = require('chai');
const { getBNEth } = require('../utils/getBN');

const NUKEToken = artifacts.require('NUKEToken');
const Auction = artifacts.require('Auction');

contract('NUKE test', async ([owner, burner, holder]) => {
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

  beforeEach(async () => {
    this.nuke = await NUKEToken.new({ from: owner });
    this.auction = await Auction.new(this.nuke.address, { from: owner });
    await this.nuke.setAuction(this.auction.address);
  });

  it('checking the nuke token parameters', async () => {
    expect(await this.nuke.name.call()).to.equal('NUKEToken');
    expect(await this.nuke.symbol.call()).to.equal('NUKE');
    expect(await this.nuke.decimals.call()).to.be.bignumber.equal(new BN('18'));
    expect(await this.nuke.totalSupply.call()).to.be.bignumber.equal(new BN('0'));
  });

  describe('check burn', async () => {
    beforeEach(async () => {
      await this.nuke.mint(getBNEth('1'), { from: owner });
    })

    it('checking isBurnAllowed function', async () => {
      expect(await this.nuke.isBurnAllowed(owner, { from: owner })).to.equal(true);
      expect(await this.nuke.isBurnAllowed(holder, { from: owner })).to.equal(false);
    });

    it('addBurner positive tests', async () => {
      expect(await this.nuke.isBurnAllowed(burner), { from: owner }).to.equal(false);
      await this.nuke.addBurner(burner, { from: owner });
      expect(await this.nuke.isBurnAllowed(burner, { from: owner })).to.equal(true);
      await expectRevert(this.nuke.addBurner(burner, { from: owner }), 'Already burner');
    });

    it('addBurner negative tests', async () => {
      await expectRevert(this.nuke.addBurner(burner, { from: holder }), 'Ownable: caller is not the owner');
      await expectRevert(this.nuke.addBurner(ZERO_ADDRESS, { from: owner }), 'Cant add zero address');
    });

    it('removeBurner positive tests', async () => {
      await this.nuke.addBurner(burner, { from: owner });
      expect(await this.nuke.isBurnAllowed(burner, { from: burner })).to.equal(true);
      await this.nuke.removeBurner(burner, { from: owner });
      expect(await this.nuke.isBurnAllowed(burner, { from: burner })).to.equal(false);
    });

    it('removeBurner negative tests', async () => {
      await expectRevert(this.nuke.removeBurner(holder, { from: owner }), 'Isnt burner');
    });

    it('burn positive tests', async () => {
      await this.nuke.burn(getBNEth('0.5'), { from: owner });
      expect(await this.nuke.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('0.5'));
    })

    it('burn negative tests', async () => {
      await expectRevert(this.nuke.burn(getBNEth('0.5'), { from: holder }), 'Caller is not burner');
      await expectRevert.unspecified(this.nuke.burn(getBNEth('1.1'), { from: owner }));
    })
  })

  describe('check mint', async () => {
    
    it('mint positive tests', async () => {
      await this.nuke.mint(getBNEth('1'), { from: owner });
      expect(await this.nuke.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('1'));
    })

    // it('mint negative tests', async () => {
    //   await expectRevert.unspecified(this.nuke.mint(getBNEth('1'), { from: burner }));
    //   await expectRevert(this.nuke.mint(getBNEth('2500001')), 'No mint over 2500000 tokens');
    //   await this.nuke.mint(getBNEth('2500000'), { from: owner });
    //   expect(await this.nuke.balanceOf(this.auction.address)).to.be.bignumber.equal(getBNEth('2500000'));
    //   await expectRevert(this.nuke.mint(getBNEth('1')), 'No mint over 2500000 tokens');
    // })
  })
  describe('check blacklist', async () => {
    it('blacklist positive tests', async () => {
      await this.nuke.addToBlacklist(holder, { from: owner });
      expect(await this.nuke.blacklistedAddresses(holder)).to.equal(true);
      await this.nuke.rempoveFromBlacklist(holder, { from: owner });
      expect(await this.nuke.blacklistedAddresses(holder)).to.equal(false);
    })

    it('blacklist negative tests', async () => {
      await this.nuke.addToBlacklist(holder, { from: owner });
      await expectRevert(this.nuke.addToBlacklist(holder, { from: owner }), 'In black list');
      await this.nuke.rempoveFromBlacklist(holder, { from: owner });
      await expectRevert(this.nuke.rempoveFromBlacklist(holder, { from: owner }), 'Not blacklisted');
      await expectRevert.unspecified(this.nuke.rempoveFromBlacklist(burner, { from: holder }));
    })
  })

  describe('check transfer', async () => {
    // it('transfer positive tests', async () => {
    //   await this.nuke.addToBlacklist(holder, { from: owner });
    // })

    // it('transfer negative tests', async () => {
    //   await this.nuke.addToBlacklist(holder, { from: owner });
    //   await expectRevert(this.nuke.transfer(owner, getBNEth('0.5'), {from: holder }), 'Blacklisted.');
    // })
  })
});
