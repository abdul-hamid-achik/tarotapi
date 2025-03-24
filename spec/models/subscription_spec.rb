require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:subscription_plan).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:plan_name) }
    it { should validate_presence_of(:status) }

    context 'when stripe_id is present' do
      before do
        create(:subscription, stripe_id: 'sub_123456')
      end

      it { should validate_uniqueness_of(:stripe_id).allow_nil }
    end
  end

  describe 'scopes' do
    before do
      @active_sub = create(:subscription, status: 'active')
      @pending_sub = create(:subscription, status: 'pending')
      @cancelled_sub = create(:subscription, status: 'cancelled')
      @expired_sub = create(:subscription, status: 'active', current_period_end: 1.day.ago)
      @current_sub = create(:subscription, status: 'active', current_period_end: 1.day.from_now)
    end

    describe '.active' do
      it 'returns subscriptions with active status' do
        expect(Subscription.active).to include(@active_sub, @current_sub, @expired_sub)
        expect(Subscription.active).not_to include(@pending_sub, @cancelled_sub)
      end
    end

    describe '.pending' do
      it 'returns subscriptions with pending status' do
        expect(Subscription.pending).to include(@pending_sub)
        expect(Subscription.pending).not_to include(@active_sub, @cancelled_sub, @expired_sub, @current_sub)
      end
    end

    describe '.cancelled' do
      it 'returns subscriptions with cancelled status' do
        expect(Subscription.cancelled).to include(@cancelled_sub)
        expect(Subscription.cancelled).not_to include(@active_sub, @pending_sub, @expired_sub, @current_sub)
      end
    end

    describe '.current' do
      it 'returns subscriptions that have not expired yet' do
        expect(Subscription.current).to include(@current_sub)
        expect(Subscription.current).not_to include(@expired_sub, @active_sub.tap { |s| s.update(current_period_end: 1.day.ago) })
      end
    end
  end

  describe 'instance methods' do
    describe '#active?' do
      it 'returns true if status is active and subscription has not expired' do
        subscription = build(:subscription, status: 'active', current_period_end: 1.day.from_now)
        expect(subscription.active?).to be true
      end

      it 'returns true if status is active and current_period_end is nil' do
        subscription = build(:subscription, status: 'active', current_period_end: nil)
        expect(subscription.active?).to be true
      end

      it 'returns false if status is not active' do
        subscription = build(:subscription, status: 'pending', current_period_end: 1.day.from_now)
        expect(subscription.active?).to be false
      end

      it 'returns false if subscription has expired' do
        subscription = build(:subscription, status: 'active', current_period_end: 1.day.ago)
        expect(subscription.active?).to be false
      end
    end

    describe '#pending?' do
      it 'returns true if status is pending' do
        subscription = build(:subscription, status: 'pending')
        expect(subscription.pending?).to be true
      end

      it 'returns false if status is not pending' do
        subscription = build(:subscription, status: 'active')
        expect(subscription.pending?).to be false
      end
    end

    describe '#cancelled?' do
      it 'returns true if status is cancelled' do
        subscription = build(:subscription, status: 'cancelled')
        expect(subscription.cancelled?).to be true
      end

      it 'returns false if status is not cancelled' do
        subscription = build(:subscription, status: 'active')
        expect(subscription.cancelled?).to be false
      end
    end

    describe '#expired?' do
      it 'returns true if current_period_end is in the past' do
        subscription = build(:subscription, current_period_end: 1.day.ago)
        expect(subscription.expired?).to be true
      end

      it 'returns false if current_period_end is in the future' do
        subscription = build(:subscription, current_period_end: 1.day.from_now)
        expect(subscription.expired?).to be false
      end

      it 'returns false if current_period_end is nil' do
        subscription = build(:subscription, current_period_end: nil)
        expect(subscription.expired?).to be false
      end
    end

    describe '#cancel!' do
      context 'when subscription is already cancelled' do
        let(:subscription) { create(:subscription, status: 'cancelled') }

        it 'returns nil without making changes' do
          expect { subscription.cancel! }.not_to change { subscription.status }
        end
      end

      context 'when subscription has a stripe_id' do
        let(:user) { create(:user) }
        let(:subscription) { create(:subscription, user: user, stripe_id: 'sub_123456', status: 'active') }
        let(:pay_subscription) { double('Pay::Subscription') }

        context 'when Pay subscription exists' do
          before do
            allow(user).to receive(:subscriptions).and_return(double('subscriptions', find_by: pay_subscription))
            allow(pay_subscription).to receive(:cancel).and_return(true)
            allow(pay_subscription).to receive(:ends_at).and_return(1.month.from_now)
          end

          it 'cancels the Pay subscription' do
            expect(pay_subscription).to receive(:cancel)
            subscription.cancel!
          end

          it 'updates the subscription status to cancelled' do
            subscription.cancel!
            expect(subscription.status).to eq('cancelled')
          end

          it 'updates the ends_at field' do
            expect { subscription.cancel! }.to change { subscription.ends_at }
          end
        end

        context 'when Pay subscription does not exist but Stripe does' do
          let(:stripe_subscription) { double('Stripe::Subscription') }

          before do
            allow(user).to receive(:subscriptions).and_return(double('subscriptions', find_by: nil))
            allow(Stripe).to receive(:api_key=)
            allow(Stripe::Subscription).to receive(:retrieve).and_return(stripe_subscription)
            allow(stripe_subscription).to receive(:cancel)
            allow(stripe_subscription).to receive(:current_period_end).and_return(Time.now.to_i + 30.days.to_i)
          end

          it 'retrieves and cancels the Stripe subscription directly' do
            expect(Stripe::Subscription).to receive(:retrieve).with('sub_123456')
            expect(stripe_subscription).to receive(:cancel)
            subscription.cancel!
          end

          it 'updates the subscription status to cancelled' do
            subscription.cancel!
            expect(subscription.status).to eq('cancelled')
          end
        end

        context 'when an error occurs' do
          before do
            allow(user).to receive(:subscriptions).and_return(double('subscriptions', find_by: pay_subscription))
            allow(pay_subscription).to receive(:cancel).and_raise(StandardError.new("Payment failed"))
          end

          it 'adds an error and returns false' do
            result = subscription.cancel!
            expect(result).to be false
            expect(subscription.errors[:base]).to include("Error canceling subscription: Payment failed")
          end
        end
      end

      context 'when subscription has no stripe_id' do
        let(:subscription) { create(:subscription, stripe_id: nil, status: 'active') }

        it 'updates the status to cancelled' do
          subscription.cancel!
          expect(subscription.status).to eq('cancelled')
        end

        it 'sets current_period_end to current time' do
          expect { subscription.cancel! }.to change { subscription.current_period_end }.to be_within(1.second).of(Time.current)
        end

        it 'returns true' do
          expect(subscription.cancel!).to be true
        end
      end
    end
  end

  describe 'class methods' do
    describe '.sync_from_pay_subscription' do
      let(:pay_subscription) do
        double('Pay::Subscription',
               processor_id: 'sub_123456',
               name: 'Premium Plan',
               processor_plan: 'premium',
               status: 'active',
               current_period_start: 1.day.ago,
               ends_at: 1.month.from_now,
               customer: double('Pay::Customer', owner_id: 1)
              )
      end

      it 'finds or initializes a subscription by stripe_id' do
        expect(Subscription).to receive(:find_or_initialize_by).with(stripe_id: 'sub_123456').and_call_original
        Subscription.sync_from_pay_subscription(pay_subscription)
      end

      it 'updates subscription attributes from pay subscription' do
        subscription = Subscription.sync_from_pay_subscription(pay_subscription)

        expect(subscription.user_id).to eq(1)
        expect(subscription.plan_name).to eq('Premium Plan')
        expect(subscription.status).to eq('active')
        expect(subscription.current_period_start).to eq(pay_subscription.current_period_start)
        expect(subscription.current_period_end).to eq(pay_subscription.ends_at)
      end

      it 'uses processor_plan when name is nil' do
        allow(pay_subscription).to receive(:name).and_return(nil)
        subscription = Subscription.sync_from_pay_subscription(pay_subscription)

        expect(subscription.plan_name).to eq('premium')
      end

      it 'returns the subscription object' do
        result = Subscription.sync_from_pay_subscription(pay_subscription)
        expect(result).to be_a(Subscription)
      end
    end

    describe '.sync_all_from_pay' do
      let(:pay_subscription1) { double('Pay::Subscription1') }
      let(:pay_subscription2) { double('Pay::Subscription2') }

      before do
        allow(Pay::Subscription).to receive(:find_each).and_yield(pay_subscription1).and_yield(pay_subscription2)
      end

      it 'syncs each Pay subscription' do
        expect(Subscription).to receive(:sync_from_pay_subscription).with(pay_subscription1)
        expect(Subscription).to receive(:sync_from_pay_subscription).with(pay_subscription2)

        Subscription.sync_all_from_pay
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      expect(build(:subscription)).to be_valid
    end
  end
end
