require 'rails_helper'

RSpec.describe ObjectManager::Attribute, type: :model do

  let(:user_attribute_permissions) do
    create(:user, roles: [role_attribute_permissions])
  end

  let(:role_attribute_permissions) do
    create(:role).tap do |role|
      role.permission_grant('admin.organization')
      role.permission_grant('ticket.agent')
    end
  end

  describe 'callbacks' do
    context 'for setting default values on local data options' do
      let(:subject) { described_class.new }

      context ':null' do
        it 'sets nil values to true' do
          expect { subject.validate }
            .to change { subject.data_option[:null] }.to(true)
        end

        it 'does not overwrite false values' do
          subject.data_option[:null] = false

          expect { subject.validate }
            .not_to change { subject.data_option[:null] }
        end
      end

      context ':maxlength' do
        context 'for data_type: select / tree_select / checkbox' do
          let(:subject) { described_class.new(data_type: 'select') }

          it 'sets nil values to 255' do
            expect { subject.validate }
              .to change { subject.data_option[:maxlength] }.to(255)
          end
        end
      end

      context ':nulloption' do
        context 'for data_type: select / tree_select / checkbox' do
          let(:subject) { described_class.new(data_type: 'select') }

          it 'sets nil values to true' do
            expect { subject.validate }
              .to change { subject.data_option[:nulloption] }.to(true)
          end

          it 'does not overwrite false values' do
            subject.data_option[:nulloption] = false

            expect { subject.validate }
              .not_to change { subject.data_option[:nulloption] }
          end
        end
      end
    end
  end

  describe 'check name' do
    it 'rejects ActiveRecord reserved word "attribute"' do
      expect do
        described_class.add attributes_for :object_manager_attribute_text, name: 'attribute'
      end.to raise_error 'attribute is a reserved word, please choose a different one'
    end

    %w[destroy true false integer select drop create alter index table varchar blob date datetime timestamp url icon initials avatar permission validate subscribe unsubscribe translate search _type _doc _id id].each do |reserved_word|
      it "rejects Zammad reserved word '#{reserved_word}'" do
        expect do
          described_class.add attributes_for :object_manager_attribute_text, name: reserved_word
        end.to raise_error "#{reserved_word} is a reserved word, please choose a different one"
      end
    end

    %w[someting_id something_ids].each do |reserved_word|
      it "rejects word '#{reserved_word}' which is used for database references" do
        expect do
          described_class.add attributes_for :object_manager_attribute_text, name: reserved_word
        end.to raise_error "Name can't get used, *_id and *_ids are not allowed"
      end
    end

    it 'rejects duplicate attribute name of conflicting types' do
      attribute = attributes_for :object_manager_attribute_text
      described_class.add attribute
      attribute[:data_type] = 'boolean'
      expect do
        described_class.add attribute
      end.to raise_error ActiveRecord::RecordInvalid
    end

    it 'accepts duplicate attribute name on the same types (editing an existing attribute)' do
      attribute = attributes_for :object_manager_attribute_text
      described_class.add attribute
      expect do
        described_class.add attribute
      end.not_to raise_error
    end

    it 'accepts duplicate attribute name on compatible types (editing the type of an existing attribute)' do
      attribute = attributes_for :object_manager_attribute_text
      described_class.add attribute
      attribute[:data_type] = 'select'
      attribute[:data_option_new] = { default: '', options: { 'a' => 'a' } }
      expect do
        described_class.add attribute
      end.not_to raise_error
    end

    it 'accepts valid attribute names' do
      expect do
        described_class.add attributes_for :object_manager_attribute_text
      end.not_to raise_error
    end
  end

  describe 'attribute permissions', db_strategy: :reset do
    it 'merges attribute permissions' do
      create(:object_manager_attribute_text, screens: { create: { 'admin.organization': { shown: true }, 'ticket.agent': { shown: false } } }, name: 'test_permissions')

      migration = described_class.migration_execute
      expect(migration).to be true

      attribute = described_class.by_object('Ticket', user_attribute_permissions).detect { |attr| attr[:name] == 'test_permissions' }
      expect(attribute[:screen]['create']['shown']).to be true
    end

    it 'overwrites permissions if all get set' do
      create(:object_manager_attribute_text, screens: { create: { '-all-': { shown: true }, 'admin.organization': { shown: false }, 'ticket.agent': { shown: false } } }, name: 'test_permissions_all')

      migration = described_class.migration_execute
      expect(migration).to be true

      attribute = described_class.by_object('Ticket', user_attribute_permissions).detect { |attr| attr[:name] == 'test_permissions_all' }
      expect(attribute[:screen]['create']['shown']).to be true
    end

    it 'is able to handle other values than true or false' do
      create(:object_manager_attribute_text, screens: { create: { '-all-': { shown: true, item_class: 'column' }, 'admin.organization': { shown: false }, 'ticket.agent': { shown: false } } }, name: 'test_permissions_item')

      migration = described_class.migration_execute
      expect(migration).to be true

      attribute = described_class.by_object('Ticket', user_attribute_permissions).detect { |attr| attr[:name] == 'test_permissions_item' }
      expect(attribute[:screen]['create']['item_class']).to eq('column')
    end
  end
end
