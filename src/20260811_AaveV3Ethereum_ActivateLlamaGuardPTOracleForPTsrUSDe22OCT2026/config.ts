import {ConfigFile} from '../../generator/types';

export const config: ConfigFile = {
  rootOptions: {
    markets: ['AaveV3Ethereum'],
    title: 'Activate LlamaGuard PT Oracle for PT-srUSDe-22OCT2026',
    shortName: 'ActivateLlamaGuardPTOracleForPTsrUSDe22OCT2026',
    date: '20260811',
    author: 'LlamaRisk',
    discussion: 'https://outline.llamarisk.com/doc/ethereum-pt-srusde-staging-0826-6axP9W0Pdy',
    snapshot: 'Direct-to-AIP',
    votingNetwork: 'AVALANCHE',
  },
  marketOptions: {
    AaveV3Ethereum: {configs: {OTHERS: {}}, cache: {blockNumber: 25732532}},
  },
};
