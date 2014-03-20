require 'observer'

module Neighborly::Balanced
  class Event
    extend Observable

    TYPES = %w(debit.created
               debit.succeeded
               bank_account_verification.deposited)

    def initialize(request_params)
      @request_params = request_params
    end

    def save
      PaymentEngine.create_payment_notification(
        contribution_id: contribution.id,
        extra_data:      @request_params[:registration].to_json
      )

      self.class.changed
      self.class.notify_observers(self)
    end

    def valid?
      valid_type? or return false

      {
        'debit.created'                       => -> { values_matches? },
        'debit.succeeded'                     => -> { values_matches? },
        # Skip validation of this type
        'bank_account_verification.deposited' => -> { true }
      }.fetch(type).call
    end

    def contribution
      Contribution.find_by(payment_id: @request_params.fetch(:entity).fetch(:id))
    end

    protected

    def type
      @request_params.fetch(:type)
    end

    def valid_type?
      TYPES.include? type
    end

    def values_matches?
      contribution.try(:price_in_cents).eql?(payment_amount)
    end

    def payment_amount
      @request_params.fetch(:entity).fetch(:amount).to_i
    end
  end
end
