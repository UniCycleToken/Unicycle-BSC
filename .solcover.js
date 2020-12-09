const fs = require('fs');

module.exports = {
  skipFiles: ['Migrations.sol', 'Mintable.sol'],
  onCompileComplete: function () {
    fs.copyFileSync('./node_modules/@uniswap/v2-periphery/build/WETH9.json', '.coverage_artifacts/contracts/WETH9.json');
    fs.copyFileSync('./node_modules/@uniswap/v2-periphery/build/UniswapV2Router02.json', '.coverage_artifacts/contracts/UniswapV2Router02.json');
    fs.copyFileSync('./node_modules/@uniswap/v2-core/build/UniswapV2Pair.json', '.coverage_artifacts/contracts/UniswapV2Pair.json');
    fs.copyFileSync('./node_modules/@uniswap/v2-core/build/UniswapV2Factory.json', '.coverage_artifacts/contracts/UniswapV2Factory.json');
  }
};
