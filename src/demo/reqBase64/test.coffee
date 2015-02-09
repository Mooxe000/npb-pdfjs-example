some_transaction = (
  knex
  rollback_err_handle
  rollback_callback
  transaction_err_handle
  transaction_callback
) ->
  knex.transaction (trx) ->
    trx.dosomething xxx
    .exec (err, result) ->
      if err
        rollback_err_handle err
      else
        rollback_callback result
  .exec (err, result) ->
    if err
      transaction_err_handle err
    else
      ransaction_callback result