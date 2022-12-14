# frozen_string_literal: true

require 'rails_helper'

describe StatusCacheHydrator do
  let(:status)  { Fabricate(:status) }
  let(:account) { Fabricate(:account) }

  describe '#hydrate' do
    let(:compare_to_hash) { InlineRenderer.render(status, account, :status) }

    shared_examples 'shared behavior' do
      context 'when handling a new status' do
        let(:poll) { Fabricate(:poll) }
        let(:status) { Fabricate(:status, poll: poll) }

        it 'renders the same attributes as a full render' do
          expect(subject).to eql(compare_to_hash)
        end
      end

      context 'when handling a new status with own poll' do
        let(:poll) { Fabricate(:poll, account: account) }
        let(:status) { Fabricate(:status, poll: poll, account: account) }

        it 'renders the same attributes as a full render' do
          expect(subject).to eql(compare_to_hash)
        end
      end

      context 'when handling a reblog' do
        let(:reblog) { Fabricate(:status) }
        let(:status) { Fabricate(:status, reblog: reblog) }

        context 'that has been favourited' do
          before do
            FavouriteService.new.call(account, reblog)
          end

          it 'renders the same attributes as a full render' do
            expect(subject).to eql(compare_to_hash)
          end
        end

        context 'that has been reblogged' do
          before do
            ReblogService.new.call(account, reblog)
          end

          it 'renders the same attributes as a full render' do
            expect(subject).to eql(compare_to_hash)
          end
        end

        context 'that has been pinned' do
          let(:reblog) { Fabricate(:status, account: account) }

          before do
            StatusPin.create!(account: account, status: reblog)
          end

          it 'renders the same attributes as a full render' do
            expect(subject).to eql(compare_to_hash)
          end
        end

        context 'that has been followed tags' do
          let(:followed_tag) { Fabricate(:tag) }

          before do
            reblog.tags << Fabricate(:tag)
            reblog.tags << followed_tag
            TagFollow.create!(tag: followed_tag, account: account, rate_limit: false)
          end

          it 'renders the same attributes as a full render' do
            expect(subject).to eql(compare_to_hash)
          end
        end

        context 'that has a poll authored by the user' do
          let(:poll) { Fabricate(:poll, account: account) }
          let(:reblog) { Fabricate(:status, poll: poll, account: account) }

          it 'renders the same attributes as a full render' do
            expect(subject).to eql(compare_to_hash)
          end
        end

        context 'that has been voted in' do
          let(:poll) { Fabricate(:poll, options: %w(Yellow Blue)) }
          let(:reblog) { Fabricate(:status, poll: poll) }

          before do
            VoteService.new.call(account, poll, [0])
          end

          it 'renders the same attributes as a full render' do
            expect(subject).to eql(compare_to_hash)
          end
        end
      end
    end

    context 'when cache is warm' do
      subject do
        Rails.cache.write("fan-out/#{status.id}", InlineRenderer.render(status, nil, :status))
        described_class.new(status).hydrate(account.id)
      end

      it_behaves_like 'shared behavior'
    end

    context 'when cache is cold' do
      subject do
        Rails.cache.delete("fan-out/#{status.id}")
        described_class.new(status).hydrate(account.id)
      end

      it_behaves_like 'shared behavior'
    end
  end
end
