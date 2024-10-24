# Development Progress for Base

## Core Development
- [x] Core development completed

## Quality Assurance (QA)
- [ ] In progress

## Supply
- [x] Supply vault major functionalities tested
- [ ] Functions dependent on borrow, staking, and interest contracts not yet tested

## Borrow
- [ ] Borrow Vault not yet tested

## Diamond
### Integration Testing
- [x] Diamond integration tested with the following facets:
  - Router
  - Governor
  - DiamondCut
  - DiamondLoupe
  - OwnershipFacet
- [ ] Integration with LoanFacet not yet tested

### Individual Testing
- [x] Router tested
- [x] Governor tested
- [x] DiamondCut tested
- [x] DiamondLoupe tested
- [x] OwnershipFacet tested
- [ ] LoanFacet not yet tested

## Deployed Contracts (Base Sepolia)

### Mock Tokens
| Token | Address |
|-------|---------|
| USDT  | 0xBFe0DEd54fd3a6F39ed0237B450440485e94c45e |
| USDC  | 0xb78D347a421c80f5815C6d7f527236f132FDc1BF |
| DAI   | 0x984536E67FA3A9164472FAD2DD56BD82530ab088 |

### Diamond
| Contract | Address |
|----------|---------|
| Diamond  | 0x0700621Ccf11418F121c2Df2649722a5ba8C8a60 |

### Access Registry
| Contract | Address |
|----------|---------|
| Implementation | 0xc159DD2ad7520a2aef72982881E8a2001Ea09C84 |
| Proxy | 0x752f7Be278C42bc64a6f8b5465D77d97A3022205 |

### Supply Tokens
| Token | Implementation Address | Proxy Address |
|-------|------------------------|---------------|
| rUSDT | 0x1F40B0367f91FdCbAC408a2174f2a619AA218fB1 | 0x19fca2D1813A4ad59FEB1B0a7B8247deAd6E3002 |
| rUSDC | 0x6353C2fb779592E6bf1035481801b49f9570a161 | 0xfbcC8a9c08fee0Ef39392cA6bAf976F2AAE12b7E |
| rDAI  | 0x29B1581485F5776580C73E5C46425ff5A2c22166 | 0xE5906C392E142CA09B90eaf3B1aB6B76861A901F |

## Next Steps
1. Complete QA process
2. Test borrow functionality
3. Test functions dependent on borrow, staking, and interest contracts in Supply
4. Complete integration testing with LoanFacet
5. Perform individual testing on LoanFacet
6. Review and update documentation as needed