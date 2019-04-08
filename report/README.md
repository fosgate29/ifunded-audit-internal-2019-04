## Editing the report

Make edits to [`living-document.md`](living-document.md).

The template links to other things, like files in the `tool-output` directory. Those files should go **directly in the `generated-report` folder.** (The only automatically generated file is `generated-report/README.md`.)

`living-document.md` is a [mustache](http://mustache.github.io/mustache.5.html) template that is used by `oddity` to generate the audit report.

For the most part, you shouldn't need to do much mustache-y stuff in `living-document.md` unless you want to change the format for displaying issues, but one feature that may come in handy is _partials_. For example, if you create a file called `threat-model.mustache`, you can include it in the report via `{{> threat-model}}`.

## Issues/formatting best practices

For best results, filed issues should follow a few simple tips:

### Use fourth-level headers

This is the right header level for where the issues appear within the report. For example:

```markdown
#### Description

#### Examples

#### Remediation

#### References
```

### Link to code

Links in issues to code, like `https://github.com/ConsenSys/ens-audit-internal-2019-02/blob/master/ethregistrar/contracts/StablePriceOracle.sol#L57-L63`, will be replaced with nicely formatted inline code. For that particular example:

**ethregistrar/contracts/StablePriceOracle.sol:L57-L63**
```solidity
function price(string calldata name, uint /*expires*/, uint duration) view external returns(uint) {
    uint len = name.strlen();
    require(len > 0);
    if(len > rentPrices.length) {
        len = rentPrices.length;
    }
    uint priceUSD = rentPrices[len - 1].mul(duration);
```

### Use remediation comments

The last comment on an issue that mentions `@oddity` will be included as the `remediation` field for the issue, which this template uses to provide issue status.

## Generating the report

To generate the report, run `oddity render`. The output will go to the [`generated-report`](generated-report) directory. You can then use `oddity preview [-b]` to preview the rendered report in the browser.

## Publishing the report

When it's time to share the report with a client, simply copy the content from the `generated-report` directory. For sharing privately, the generated report will typically go into a brand new repo which the client gets read-only access to. For public audits, we will establish a shared repository in the future.
