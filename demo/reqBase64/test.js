var some_transaction;

some_transaction = function(knex, rollback_err_handle, rollback_callback, transaction_err_handle, transaction_callback) {
  return knex.transaction(function(trx) {
    return trx.dosomething(xxx).exec(function(err, result) {
      if (err) {
        return rollback_err_handle(err);
      } else {
        return rollback_callback(result);
      }
    });
  }).exec(function(err, result) {
    if (err) {
      return transaction_err_handle(err);
    } else {
      return ransaction_callback(result);
    }
  });
};
