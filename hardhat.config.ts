import * as path from "path"

import "@nomicfoundation/hardhat-foundry"
import "@nomicfoundation/hardhat-toolbox"
import "@openzeppelin/hardhat-upgrades"
import { HardhatUserConfig, subtask } from "hardhat/config"

// Needed to support typescript paths mappings
import "tsconfig-paths/register"

// Modify TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS to include solidity files in
// the tests/ directory.
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names"
subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS, async (_, hre, runSuper) => {
  const paths = await runSuper()

  // Include specific test files in tests/ for hardhat tests.
  const testDir = path.join(hre.config.paths.root, "tests")
  const extraPaths = [path.join(testDir, "TestContracts.sol")]
  return [...paths, ...extraPaths]
})

//const INFURA_API_KEY = process.env.INFURA_API_KEY
const ARBITRUM_SEPOLIA_ALCHEMY_API_KEY = process.env.ARBITRUM_SEPOLIA_ALCHEMY_API_KEY
const ARBITRUM_SEPOLIA_QUICKNODE_HTTPS = process.env.ARBITRUM_SEPOLIA_QUICKNODE_HTTPS

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      evmVersion: "shanghai",
      optimizer: {
        enabled: true,
        runs: 50_000,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./tests",
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
  },
}

export default config
