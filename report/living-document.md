# iFunded Audit

<img height="100px" Hspace="30" Vspace="10" align="right" src="static-content/diligence.png"/>

{{toc}}

## Summary

ConsenSys Diligence conducted a security audit on the security token standard implemented by iEstate GmbH, as well as the voting system, interest distribution and the whitelist management.

### Audit Dashboard
________________

#### Audit Details

* **Project Name: iFunded**
* **Client Name: iEstate GmbH**
* **Client Website: https://iestate.de/**
* **Client Contact: Greg Freeman**
* **Lead Auditor: Daniel Luca**
* **Co-auditors: John Mardlin, Steve Marx, Martin Ortner**
* **Date: 29 April 2019**
* **Commit hash: 55cde0edba01488d99ac84a42b8e36f4ed8cdae3**

#### Number of issues by severity

| {{#severities}}| **{{.}}** {{/severities}}|
|:-------------:|:-------------:|:-------------:|:-------------:|:-------------:|
{{#count_by_state}}
| **{{state}}** {{#counts}}| **{{.}}** {{/counts}}|
{{/count_by_state}}

________________

### Audit Goals

The focus of the audit was to verify that the smart contract system is secure, resilient and working according to its specifications. The audit activities can be grouped in the following three categories:

**Security:** Identifying security related issues within each contract and within the system of contracts.

**Sound Architecture:** Evaluation of the architecture of this system through the lens of established smart contract best practices and general software best practices.

**Code Correctness and Quality:** A full review of the contract source code. The primary areas of focus include:

* Correctness
* Readability
* Sections of code with high complexity
* Improving scalability
* Quantity and quality of test coverage

### System Overview

#### Documentation

The following documentation was available to the audit team:

- Security Token Platform Technical Overview [private document]
- Assumptions for the audit [private document]

#### Detail

Top level contracts and libraries: 

- SecurityToken
- TokenVoting
- PlatformProviderRbac
- DefaultSecurityTokenWhitelist
- InterestDistribution
- SafeMath
- KindMath

<img src="tool-output/surya/inheritance.png" />

#### Scope

The scope of the audit was defined as the Solidity code in the `./contracts/` folder except for `TestPaymentToken` and `Migrations`.

The list of files and their hashes can be found in [Appendix - File Hashes](#7-appendix---file-hashes).

#### Design

The whole system is built around 4 major contracts:

- **DefaultSecurityTokenWhitelist**

  The operator grants permission to investors to interact with the security tokens. They can be added or removed from the approved list. Whenever an investor is added to the list, a cryptographic hash is pinned in the smart contract state which represents the investor's verified information.

- **TokenVoting**

  Implements partition based voting functionality. Actors can propose votes for a partition, with arbitrary voting options and they specify who can vote on the topic. Each vote is pinned to an Ethereum block number. The voters have the same weight when they vote, each actor's vote counts as 1. The on chain functionality does not define a weight attached to the amount of ether or tokens they own, however off chain a vote weighting can be done if needed. The smart contract can be used as proof for the option each voter has selected.

- **SecurityToken**

  This is the main part of the application which implements the [ERC 1400](https://github.com/ethereum/EIPs/issues/1400) also known as [Security Token Standard](https://thesecuritytokenstandard.org/). It is a group of standards that aim to create a representation of securities on the Ethereum blockchain. It is comprised of:
  - [ERC 1410 - Partially Fungible Token Standard](https://github.com/ethereum/EIPs/issues/1410)
  - [ERC 1594 - Core Security Token Standard](https://github.com/ethereum/EIPs/issues/1594)
  - [ERC 1643 - Document Management Standard](https://github.com/ethereum/EIPs/issues/1643)
  - [ERC 1644 - Controller Token Operation Standard](https://github.com/ethereum/EIPs/issues/1644)

  Is compatible with [ERC 20](https://github.com/ethereum/EIPs/issues/20) and [ERC 777](https://github.com/ethereum/EIPs/issues/777).

- **InterestDistribution**

    The `InterestDistribution` contract can hold ether and other tokens. Ether and other tokens may be deposited, and whitelisted accounts may specify the amount of tokens which can be claimed by an address.

    Notably, this contract does not reference the state of any Security Tokens, or verify the calculation used to determine the payments. It simply enables the operators of the iFunded platform to distribute payments in any amount, to any token, and to any address. This approach avoids the cost of on-chain computation, while enabling the iEstate platform to publish the methodology for calculating payouts based on tokens held at a given time, and for token holders to independently verify the calculations.

### Key Observations/Recommendations

Positive observations:

- The design of the system adheres to the reference implementation.
- The methods have comments that describe the functionality and the parameters.
- The Solidity smart contracts are split into multiple files, most of the time being comprised out of an interface and an implementation.
- The arithmetic operations are checked with `KindMath` and are safely finalized with `SafeMath`.
- There is a fair number of tests checking the proper functionality of the application.
- Best practices are followed where they make sense.
- No major issues were found in the code.

Opportunities for improvement:

- Test coverage is incomplete. It is a good practice to have 100% code coverage. In particular it's useful to include negative test cases ensuring that undesirable actions are impossible.  
- There are instances where contracts are split into a large number of files, making the inheritance tree difficult to reason about.
- Both safety and efficiency can be improved by reviewing for the correct use of the keywords  `public` and `external` on functions.
- A glossary of terms could be helfpul to people who come from a financial background, as well as blockchain developers trying to understand the securities terminology.
- Code readability can be improved by adopting a consistent formatting scheme, particularly with respect to indentation and whitespace in function declaration. 

## Issue Overview

The following table contains all the issues discovered during the audit. The issues are ordered based on their severity. More detailed description on the levels of severity can be found in the Severity Definitions Appendix. The table also contains the status of any discovered issue.

| Chapter      | Issue Title             | Issue Status | Severity    |
| ------------ | ----------------------- | ------------ | ----------- |
{{#issues}}
| {{section}}  | [{{ title }}]({{link}}) | {{ state }}  | {{ severity }} |
{{/issues}}

## Issue Details

{{#issues}}
### {{title}} {{anchor}}

| Severity     | Status    | Remediation Comment |
| ------------ | --------- | ------------------- |
| {{severity}} | {{state}} | {{#remediation}}{{.}}{{/remediation}}{{^remediation}}This issue is currently under review.{{/remediation}} |

{{{body}}}
{{/issues}}

## Threat Model

The creation of a threat model is beneficial when building smart contract systems as it helps to understand the potential security threats, assess risk, and identify appropriate mitigation strategies. This is especially useful during the design and development of a contract system as it allows to create a more resilient design which is more difficult to change post-development.

A threat model was created during the audit process in order to analyze the attack surface of the contract system and to focus review and testing efforts on key areas that a malicious actor would likely also attack. It consists of two parts a high level design diagram that help to understand the attack surface and a list of threats that exist for the contract system.

### Overview

#### Actors

##### Owner

The owner has some special permissions in the contracts that inherit `OwnableNonTransferable`. Permissions vary based on the contract. The owners can be different or the owners can have the same identity. The ownership is not transferrable, so taking care of the owner's private key is important. In case the private key is compromised, another instance of the contract has to be deployed, abandoning the old instance.

The owner can:
- add and remove links to documents;
- withdraw (residual) interest;
- add and remove operators;
- renounce ownership.

##### Operator

The operator has an important impact in the application. It is the actor that can force transfer tokens in or out of the investors' portfolio, can set interest payment for withdrawal, can pause, unpause, mint or burn tokens.

The private key has to be handled with special care, considering the actions it has to perform happen periodically and cannot be stored in a cold storage with no access for a long period of time.

##### Investor

The investors are the external users that initially have to be verified off chain, and whitelisted on chain to be able to transact the tokens. They do not have any special permissions and by design they should only interact with the tokens and the interest distribution contract.

##### Voter

The voters are another type of actor which exists only in the context of voting. When the vote is created, a list of voters is added; this list can be later extended for the same vote. The implementation does not enforce a relationship with the **investors**, they can have the same identity or a different one.

#### Assets

Assets must be protected, as potential threats could result in considerable loss for the actors, can erode the system's trust or have legal repercussions. The following assets were identified:

- **Private keys**: a fair number of different private keys have special control over features in the contracts.
- **Deployed contracts**: the instances of the on chain deployed contracts are considered an asset.
- **Documents**: documents with private information handled by the ERC 1643 implementation; the documents are not added on chain, however there is a URI and a hash pinned in the contract.
- **Whitelist**: the list of approved investors.
- **Interest**: in the form of ether and ERC 20 tokens.
- **Investor balances**: the ledger representing investor balances.
- **Partitions**: represent different slates of investor balances with specific sets of rules.

## Tool-Based Analysis

Several tools were used to perform automated analysis of the reviewed contracts. These issues were reviewed by the audit team, and relevant issues are listed in the Issue Details section.

### Mythril

<img height="120px" align="right" src="static-content/mythril.png"/>

Mythril is a security analysis tool for Ethereum smart contracts. It uses concolic analysis to detect various types of issues. The tool was used for automated vulnerability discovery for all audited contracts and libraries. More details on Mythril's current vulnerability coverage can be found [here](https://github.com/ConsenSys/mythril/wiki).

The raw output of the Mythril vulnerability scan can be found [here](./tool-output/mythril/mythril_report.md).

### Ethlint

<img height="120px" align="right" src="static-content/ethlint.png"/>

[Ethlint](https://www.ethlint.com/) is an open source project for linting Solidity code. Only security-related issues were reviewed by the audit team.

The raw output of the Ethlint vulnerability scan can be found [here](./tool-output/ethlint/ethlint_report.md).

### Surya

Surya is an utility tool for smart contract systems. It provides a number of visual outputs and information about structure of smart contracts. It also supports querying the function call graph in multiple ways to aid in the manual inspection and control flow analysis of contracts.

#### Surya Outputs

1. A complete list of functions with their visibility and modifiers can be found [here](./tool-output/surya/surya_report.md).
2. A visualization of the system's function call graph can be found [here](./tool-output/surya/callgraph.png).
3. A visualization of the system's inheritance graph can be found [here](./tool-output/surya/inheritance.png).

## Test Coverage Measurement

Testing is implemented using Truffle. 134 tests are included in the test suite, and they all pass.

A code coverage report was included in the client repository. The state of test coverage we were provided can be viewed by opening the `index.html` file from the [coverage report](coverage-report) directory in a browser. Below is a summary of the coverage results:

File                                |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
------------------------------------|----------|----------|----------|----------|----------------|
 contracts/                         |       80 |       50 |      100 |       80 |                |
&nbsp; SecurityToken.sol            |       80 |       50 |      100 |       80 |         95,100 |
 contracts/ERC/ERC1400/             |    93.55 |       50 |    88.24 |    95.12 |                |
&nbsp; ERC1400.sol                  |    93.55 |       50 |    88.24 |    95.12 |        135,144 |
 contracts/ERC/ERC1410/             |     90.2 |    69.39 |    93.62 |    92.68 |                |
&nbsp; ERC1410.sol                  |     90.2 |    69.39 |    93.62 |    92.68 |... 805,832,833 |
  IERC1410.sol                      |      100 |      100 |      100 |      100 |                |
 contracts/ERC/ERC1594/             |      100 |      100 |      100 |      100 |                |
&nbsp; IERC1594.sol                 |      100 |      100 |      100 |      100 |                |
 contracts/ERC/ERC1643/             |      100 |       90 |      100 |      100 |                |
&nbsp; ERC1643.sol                  |      100 |       90 |      100 |      100 |                |
&nbsp; IERC1643.sol                 |      100 |      100 |      100 |      100 |                |
 contracts/ERC/ERC1644/             |      100 |      100 |      100 |      100 |                |
&nbsp; IERC1644.sol                 |      100 |      100 |      100 |      100 |                |
 contracts/ERC/ERC20/               |      100 |      100 |      100 |      100 |                |
&nbsp; IERC20.sol                   |      100 |      100 |      100 |      100 |                |
 contracts/access/                  |      100 |    52.94 |      100 |      100 |                |
&nbsp; ReentrancyGuard.sol          |      100 |       50 |      100 |      100 |                |
&nbsp; RoleBasedAccessControl.sol   |      100 |    53.13 |      100 |      100 |                |
 contracts/access/iEstate/          |    77.78 |        0 |       80 |    63.64 |                |
&nbsp; PlatformProviderRbac.sol     |    77.78 |        0 |       80 |    63.64 |    28,29,37,38 |
 contracts/math/                    |    37.93 |       20 |       50 |    37.93 |                |
&nbsp; KindMath.sol                 |    38.46 |       25 |    66.67 |    38.46 |... 23,25,35,44 |
&nbsp; SafeMath.sol                 |     37.5 |    16.67 |       40 |     37.5 |... 31,34,62,63 |
 contracts/ownership/               |      100 |    83.33 |      100 |      100 |                |
&nbsp; OwnableNonTransferable.sol   |      100 |    83.33 |      100 |      100 |                |
 contracts/whitelists/              |    95.65 |    58.33 |      100 |       96 |                |
&nbsp; FungibleWhitelist.sol        |    95.65 |    58.33 |      100 |       96 |            142 |
&nbsp; IFungibleWhitelist.sol       |      100 |      100 |      100 |      100 |                |
 contracts/whitelists/iEstate/      |      100 |      100 |      100 |      100 |                |
&nbsp; DefaultSecurityTokenWhitelist|      100 |      100 |      100 |      100 |                |
&nbsp;                              |          |          |          |          |                |
**All files**                       |**86.93** | **59.8** |**90.76** |**88.46** |                |

It's important to note that "100% test coverage" is not a silver bullet. Our review also included a inspection of the test suite to ensure that testing included important edge cases.

## **Appendix - File Hashes**

The SHA1 hashes of the source code files in scope of the audit are listed in the table below:

|                       File Name                       |                SHA-1 Hash                |
| ----------------------------------------------------- | ---------------------------------------- |
| ERC/ERC1400/ERC1400.sol                               | b5023882742c1c4e221e6310d5d1ae4e1ac68520 |
| ERC/ERC1410/ERC1410.sol                               | 2ff5b60fa291baa0bbe31d9e67ff5cc42f1570c6 |
| ERC/ERC1410/IERC1410.sol                              | 960310022fe4917c48db82fd5b9cb624234b3484 |
| ERC/ERC1594/IERC1594.sol                              | 779458669335a1ed0a2d37b5091060792d0ac657 |
| ERC/ERC1643/ERC1643.sol                               | 43c6f59e80662acdf6a445b7d3b77cba5311d1ed |
| ERC/ERC1643/IERC1643.sol                              | 62177ffceba689c20bfb3881211afd82bddb8ab3 |
| ERC/ERC1644/IERC1644.sol                              | f323ebd9915d769d67192746da0d5f440859133e |
| ERC/ERC20/IERC20.sol                                  | 057595249d07e6068ac63a5203378f3f2743ab19 |
| InterestDistribution/IInterestDistribution.sol        | 1e8957279b5fb1b9e2767189e96854190b9a41ff |
| InterestDistribution/iEstate/InterestDistribution.sol | 8ffb342464644056792125b2d2004bb9e3310837 |
| SecurityToken.sol                                     | 4f7b854672fd6315290698fb27425ad46dd323ac |
| TokenVoting.sol                                       | b28105766c3d4351c350a0e50025c30b3fc347db |
| access/ReentrancyGuard.sol                            | 1d49b154313d96845c125f4f867234cf48531382 |
| access/RoleBasedAccessControl.sol                     | f279cd2407a5c5d9e1c1460c688471f951e50ef0 |
| access/iEstate/PlatformProviderRbac.sol               | fda1acf285b492d5f8ebfa85748de29ae4151a99 |
| math/KindMath.sol                                     | 371a5172dc4c991cd8699f0458a849eba59800a5 |
| math/SafeMath.sol                                     | 78878dc3bbedb82dffa9c909d31017c15c5638d4 |
| ownership/OwnableNonTransferable.sol                  | 8123aabe4c0bd1a6580446f5c3536eeba3ade739 |
| whitelists/FungibleWhitelist.sol                      | 37dbfc7274708ad86152eb627ea44fce15f3d31f |
| whitelists/IFungibleWhitelist.sol                     | 59440a4b8b8f5d4059509e2fc47c4783bb843de1 |
| whitelists/iEstate/DefaultSecurityTokenWhitelist.sol  | 6cc2a2f93a7d345ed96747f91cc20c9acfd81121 |

## Appendix - Severity

### Minor

Minor issues are generally subjective in nature, or potentially deal with topics like "best practices" or "readability".  Minor issues in general will not indicate an actual problem or bug in code.

The maintainers should use their own judgment as to whether addressing these issues improves the codebase.

### Medium

Medium issues are generally objective in nature but do not represent actual bugs or security problems.

These issues should be addressed unless there is a clear reason not to.

### Major

Major issues will be things like bugs or security vulnerabilities.  These issues may not be directly exploitable, or may require a certain condition to arise in order to be exploited.

Left unaddressed these issues are highly likely to cause problems with the operation of the contract or lead to a situation which allows the system to be exploited in some way.

### Critical

Critical issues are directly exploitable bugs or security vulnerabilities.

Left unaddressed these issues are highly likely or guaranteed to cause major problems or potentially a full failure in the operations of the contract.

## Appendix - Disclosure

ConsenSys Diligence (“CD”) typically receives compensation from one or more clients (the “Clients”) for performing the analysis contained in these reports (the “Reports”). The Reports may be distributed through other means, including via ConsenSys publications and other distributions.

The Reports are not an endorsement or indictment of any particular project or team, and the Reports do not guarantee the security of any particular project. This Report does not consider, and should not be interpreted as considering or having any bearing on, the potential economics of a token, token sale or any other product, service or other asset. Cryptographic tokens are emergent technologies and carry with them high levels of technical risk and uncertainty. No Report provides any warranty or representation to any Third-Party in any respect, including regarding the bugfree nature of code, the business model or proprietors of any such business model, and the legal compliance of any such business. No third party should rely on the Reports in any way, including for the purpose of making any decisions to buy or sell any token, product, service or other asset. Specifically, for the avoidance of doubt, this Report does not constitute investment advice, is not intended to be relied upon as investment advice, is not an endorsement of this project or team, and it is not a guarantee as to the absolute security of the project. CD owes no duty to any Third-Party by virtue of publishing these Reports.

PURPOSE OF REPORTS The Reports and the analysis described therein are created solely for Clients and published with their consent. The scope of our review is limited to a review of Solidity code and only the Solidity code we note as being within the scope of our review within this report. The Solidity language itself remains under development and is subject to unknown risks and flaws. The review does not extend to the compiler layer, or any other areas beyond Solidity that could present security risks. Cryptographic tokens are emergent technologies and carry with them high levels of technical risk and uncertainty.

CD makes the Reports available to parties other than the Clients (i.e., “third parties”) -- on its GitHub account (https://github.com/ConsenSys). CD hopes that by making these analyses publicly available, it can help the blockchain ecosystem develop technical best practices in this rapidly evolving area of innovation.

LINKS TO OTHER WEB SITES FROM THIS WEB SITE You may, through hypertext or other computer links, gain access to web sites operated by persons other than ConsenSys and CD. Such hyperlinks are provided for your reference and convenience only, and are the exclusive responsibility of such web sites' owners. You agree that ConsenSys and CD are not responsible for the content or operation of such Web sites, and that ConsenSys and CD shall have no liability to you or any other person or entity for the use of third party Web sites. Except as described below, a hyperlink from this web Site to another web site does not imply or mean that ConsenSys and CD endorses the content on that Web site or the operator or operations of that site. You are solely responsible for determining the extent to which you may use any content at any other web sites to which you link from the Reports. ConsenSys and CD assumes no responsibility for the use of third party software on the Web Site and shall have no liability whatsoever to any person or entity for the accuracy or completeness of any outcome generated by such software.

TIMELINESS OF CONTENT The content contained in the Reports is current as of the date appearing on the Report and is subject to change without notice. Unless indicated otherwise, by ConsenSys and CD.
