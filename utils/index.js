// eslint-disable-next-line import/no-extraneous-dependencies
import BN from 'openzeppelin-test-helpers';

function getBigNumber(modulus) {
  return (num) => {
    let res = num.toString();
    for (let i = 0; i < modulus - num.toString().length; i += 1) {
      res += ('0');
    }
    return new BN(res);
  };
}

const getBNEth = getBigNumber(18);
const getBNUSDT = getBigNumber(6);

module.exports = {
  getBNEth,
  getBNUSDT,
};
