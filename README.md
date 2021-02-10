```sh
git clone git@github.com:dapp-org/radicle-contract-tests.git --recursive
nix-shell
dapp test --rpc-url <ETH_RPC_URL>
```

### Deployment Checklist
- [ ] balanceOf tokensHolder == rad.totalSupply
- [ ] timelock.admin == address(governor)
- [ ] ens == 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85 (public ens base registrar implementation) 
