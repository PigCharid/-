require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [    //可指定多个sol版本
        {version: "0.8.19"},
        {version: "0.6.6"},
        {version: "0.5.16"}
    ]
}
};
