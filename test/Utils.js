const { ether } = require('@openzeppelin/test-helpers');

const cycle = n => ether(n);

module.exports = {
  cycle,
};