const {
  BN,
// eslint-disable-next-line import/no-extraneous-dependencies
} = require('openzeppelin-test-helpers');

function getBigNumber(modulus) {
  return (num) => {
    if (num === '0') {
      return '0';
    }
    if (+num < 1) {
      let res = num;
      for (let i = 0; i < modulus - num.length + 2; i += 1) {
        res += ('0');
      }
      return num.length <= (modulus + 1) ? new BN(res.substring(res.search(/[1-9]/))) : '0';
    }
    if (+num >= 1) {
      let res = num;
      const lengthToAdd = num.slice(0, num.indexOf('.')).length;
      for (let i = 0; i < modulus; i += 1) {
        res += ('0');
      }
      return res.indexOf('.') > 0 ? new BN(res.replace('.', '').slice(0, modulus + lengthToAdd)) : new BN(res);
    }
  };
}

const getBNEth = getBigNumber(18);
const getBNUSDT = getBigNumber(6);

module.exports = {
  getBNEth,
  getBNUSDT,
};
