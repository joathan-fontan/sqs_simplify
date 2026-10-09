# Changelog

## 0.2.0

- Consumer interrupts a message that runs out of time with `SqsSimplify::Errors::ExecutionExpired` instead of `throw`, so open database transactions roll back instead of being committed halfway.
- Consumer keeps the message (no delete) when the perform runs past its deadline, even if the application swallowed the timeout.
- `group_id` support for FIFO queues in `Scheduler` and `Message`.
- Worker options `worker_size` and `parallel_type` passed through the command line.
- `SqsSimplify::Command#daemonize` renamed to `#run`; the `daemons` dependency was removed.
- Dependencies relaxed to `aws-sdk-sqs ~> 1.0` and `parallel >= 1.20, < 3`; Ruby >= 3.0.

## 0.1.0

- Initial version.
