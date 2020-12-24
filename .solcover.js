const fs = require('fs');

module.exports = {
  skipFiles: ['Migrations.sol', 'Mintable.sol'],
  onCompileComplete: function (config) {
    fs.copyFileSync(config.working_directory + '/node_modules/@uniswap/v2-periphery/build/WETH9.json', config.contracts_build_directory + '/WETH9.json');
    fs.copyFileSync(config.working_directory + '/node_modules/@uniswap/v2-periphery/build/UniswapV2Router02.json', config.contracts_build_directory + '/UniswapV2Router02.json');
    fs.copyFileSync(config.working_directory + '/node_modules/@uniswap/v2-core/build/UniswapV2Pair.json', config.contracts_build_directory + '/UniswapV2Pair.json');
    fs.copyFileSync(config.working_directory + '/node_modules/@uniswap/v2-core/build/UniswapV2Factory.json', config.contracts_build_directory + '/UniswapV2Factory.json');
  }
};
