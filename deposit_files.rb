require_relative 'lib/deposit_file'

Mail.defaults do
  delivery_method :sendmail
end

deposits = FileQA::get_deposits('tmp')
FileQA::deposit_files('tmp', deposits)
