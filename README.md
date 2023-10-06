# da-tre-tf-module-da-eventbus-to-s3
A module to dump messages from tre-out to S3 with a filter and partitioning rules

Current Config:

Filter ```uk.gov.nationalarchives.tre.messages.judgmentpackage.available.JudgmentPackageAvailable```

and partition them to S3 as:

```<bucket>/judgmentpackage.available.JudgmentPackageAvailable/originator/reference/<the raw message>```

e.g. ```judgmentpackage.available.JudgmentPackageAvailable/ABC/ABC-123```
