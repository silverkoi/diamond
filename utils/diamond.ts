import type { AddressLike, BaseContract, FunctionFragment } from "ethers"

export enum FacetCutAction {
  Add = 0,
  Replace = 1,
  Remove = 2,
}

export interface FacetCut {
  facetAddress: AddressLike
  action: FacetCutAction
  functionSelectors: string[]
}

// Returns a map of function name to function selector using the ABI of the provided contract.
export function getSelectorsByName(contract: BaseContract): Map<string, string> {
  const selectors = new Map<string, string>()
  contract.interface.forEachFunction((f: FunctionFragment) => {
    selectors.set(f.name, f.selector)
  })
  return selectors
}

export function getSelectors(contract: BaseContract, functionNames?: string[]): string[] {
  const selectorsMap = getSelectorsByName(contract)
  const selectors: string[] = []
  for (const [name, selector] of selectorsMap) {
    if (!functionNames || functionNames.includes(name)) {
      selectors.push(selector)
    }
  }
  return selectors
}
