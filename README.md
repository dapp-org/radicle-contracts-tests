```sh
git clone git@github.com:dapp-org/radicle-contract-tests.git --recursive
nix-shell
dapp test --rpc-url <ETH_RPC_URL>
```

### Deployment Checklist
- [ ] balanceOf tokensHolder == rad.totalSupply
- [ ] timelock.admin == address(governor)
- [ ] ens == 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e (public ens base registrar implementation) 
