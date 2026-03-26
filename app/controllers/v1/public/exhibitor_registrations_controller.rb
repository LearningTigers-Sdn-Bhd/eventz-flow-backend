# frozen_string_literal: true

module V1
  module Public
    class ExhibitorRegistrationsController < ApplicationController
      class ZoneSoldOutError < StandardError; end
      class BoothPriceSoldOutError < StandardError; end

      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def booth_prices
        event = Event.friendly.find(params[:event_slug])

        prices = event.exhibitor_booth_prices.includes(:exhibitor_zone).order(:booth_type, :label)
        zone_sold_map = zone_sold_counts(event)
        booth_price_sold_map = booth_price_sold_counts(event)

        render json: {
          success: true,
          data: prices.map do |price|
            zone_quota = price.exhibitor_zone&.quota
            zone_sold_count = zone_sold_map[price.exhibitor_zone_id].to_i
            zone_remaining = zone_quota.nil? ? nil : [zone_quota - zone_sold_count, 0].max
            booth_price_quota = price.quota
            booth_price_sold_count = booth_price_sold_map[price.id].to_i
            booth_price_remaining = booth_price_quota.nil? ? nil : [booth_price_quota - booth_price_sold_count, 0].max
            zone_available = zone_quota.nil? || zone_remaining.positive?
            booth_quota_available = booth_price_quota.nil? || booth_price_remaining.positive?

            {
              id: price.id,
              booth_type: price.booth_type,
              zone: price.zone,
              exhibitor_zone_id: price.exhibitor_zone_id,
              label: price.label,
              price: price.price,
              zone_quota: zone_quota,
              zone_sold_count: zone_sold_count,
              zone_remaining: zone_remaining,
              zone_available: zone_available,
              booth_price_quota: booth_price_quota,
              booth_price_sold_count: booth_price_sold_count,
              booth_price_remaining: booth_price_remaining,
              booth_price_available: zone_available && booth_quota_available
            }
          end
        }
      end

      def status
        event = Event.friendly.find(params[:event_slug])
        exhibitor_kit_id = params[:exhibitor_kit_id].to_i
        email = params[:email].to_s.strip.downcase

        exhibitor_kit = if exhibitor_kit_id.positive?
                          find_exhibitor_kit_for_event!(event: event, exhibitor_kit_id: exhibitor_kit_id)
                        else
                          if email.blank?
                            return render json: { success: false, message: 'Email is required' }, status: :unprocessable_content
                          end

                          find_existing_registration(event: event, email: email)
                        end

        render json: { success: true, data: serialize_registration_status(exhibitor_kit) }
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event or exhibitor registration not found' }, status: :not_found
      end

      def create
        event = Event.friendly.find(params[:event_slug])

        unless event.published? && event.use_exhibitor_kit?
          return render json: {
            success: false,
            message: 'Registration is not open for this event'
          }, status: :unprocessable_content
        end

        email = registration_params[:pic_email_address].to_s.strip.downcase
        if email.blank?
          return render json: { success: false, message: 'Email is required' }, status: :unprocessable_content
        end

        booth_price = event.exhibitor_booth_prices.find(params[:exhibitor_booth_price_id])

        existing_kit = find_existing_registration(event: event, email: email)
        if existing_kit.present?
          return render json: {
            success: true,
            data: serialize_existing_registration(existing_kit)
          }, status: :ok
        end

        exhibitor_kit = create_registration!(event: event, booth_price: booth_price)

        render json: {
          success: true,
          data: {
            exhibitor_kit_id: exhibitor_kit.id,
            price: exhibitor_kit.amount_paid,
            payment_option: registration_params[:payment_option].to_s == 'later' ? 'later' : 'now',
            payment_required: registration_params[:payment_option].to_s != 'later',
            exhibitor_kit: serialize_exhibitor_kit(exhibitor_kit)
          }
        }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { success: false, errors: e.record.errors.full_messages }, status: :unprocessable_content
      rescue ZoneSoldOutError
        render json: { success: false, message: 'Selected zone is sold out' }, status: :unprocessable_content
      rescue BoothPriceSoldOutError
        render json: { success: false, message: 'Selected booth package is sold out' }, status: :unprocessable_content
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event or booth price not found' }, status: :not_found
      end

      def update
        event = Event.friendly.find(params[:event_slug])

        email = registration_params[:pic_email_address].to_s.strip.downcase
        if email.blank?
          return render json: { success: false, message: 'Email is required' }, status: :unprocessable_content
        end

        exhibitor_kit_id = params[:exhibitor_kit_id].to_i
        if exhibitor_kit_id <= 0
          return render json: { success: false, message: 'Exhibitor registration is required' },
                        status: :unprocessable_content
        end

        booth_price = event.exhibitor_booth_prices.find(params[:exhibitor_booth_price_id])
        existing_kit = find_exhibitor_kit_for_event!(event: event, exhibitor_kit_id: exhibitor_kit_id)

        unless registration_email_matches?(exhibitor_kit: existing_kit, email: email)
          return render json: { success: false, message: 'Exhibitor registration not found for this email' },
                        status: :not_found
        end

        updated_kit = update_existing_registration!(existing_kit: existing_kit, booth_price: booth_price)

        render json: {
          success: true,
          data: serialize_existing_registration(updated_kit)
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { success: false, errors: e.record.errors.full_messages }, status: :unprocessable_content
      rescue ZoneSoldOutError
        render json: { success: false, message: 'Selected zone is sold out' }, status: :unprocessable_content
      rescue BoothPriceSoldOutError
        render json: { success: false, message: 'Selected booth package is sold out' }, status: :unprocessable_content
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event or booth price not found' }, status: :not_found
      end

      def upload_payment_proof
        event = Event.friendly.find(params[:event_slug])
        exhibitor_kit = find_exhibitor_kit_for_event!(event: event, exhibitor_kit_id: params[:exhibitor_kit_id])

        zone = exhibitor_kit.custom_fields_data&.dig('zone') || exhibitor_kit.exhibitor_booth_price&.zone
        unless manual_payment_zone?(zone)
          return render json: {
            success: false,
            message: 'Payment proof upload is only required for Zone A, B, or C'
          }, status: :unprocessable_content
        end

        payment_proof = params[:payment_proof]
        if payment_proof.blank?
          return render json: { success: false, message: 'Payment proof is required' }, status: :unprocessable_content
        end

        unless allowed_payment_proof_type?(payment_proof)
          return render json: {
            success: false,
            message: 'Payment proof must be a JPEG, PNG, GIF, WebP, or PDF'
          }, status: :unprocessable_content
        end

        if payment_proof.size.to_i > 20.megabytes
          return render json: {
            success: false,
            message: 'Payment proof is too large (max 20MB)'
          }, status: :unprocessable_content
        end

        exhibitor_kit.payment_proof.attach(payment_proof)

        render json: {
          success: true,
          data: {
            exhibitor_kit_id: exhibitor_kit.id,
            payment_proof_uploaded: exhibitor_kit.payment_proof.attached?,
            payment_proof_url: exhibitor_kit.payment_proof.attached? ? url_for(exhibitor_kit.payment_proof) : nil
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event or exhibitor registration not found' }, status: :not_found
      end

      def remove_payment_proof
        event = Event.friendly.find(params[:event_slug])
        exhibitor_kit = find_exhibitor_kit_for_event!(event: event, exhibitor_kit_id: params[:exhibitor_kit_id])

        exhibitor_kit.payment_proof.purge_later if exhibitor_kit.payment_proof.attached?

        render json: {
          success: true,
          data: {
            exhibitor_kit_id: exhibitor_kit.id,
            payment_proof_uploaded: false,
            payment_proof_url: nil
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event or exhibitor registration not found' }, status: :not_found
      end

      private

      def update_existing_registration!(existing_kit:, booth_price:)
        ActiveRecord::Base.transaction do
          user = find_or_create_vendor_user!
          upsert_vendor_profile!(user)

          existing_kit.event_vendor.event.with_lock do
            unless existing_kit.exhibitor_booth_price_id == booth_price.id
              ensure_zone_capacity!(booth_price: booth_price)
            end

            existing_kit.update!(build_exhibitor_kit_attributes(booth_price))
            existing_kit
          end
        end
      end

      def create_registration!(event:, booth_price:)
        ActiveRecord::Base.transaction do
          user = find_or_create_vendor_user!
          upsert_vendor_profile!(user)

          event.with_lock do
            exhibitor = Exhibitor.find_by(event: event, vendor: user)

            return exhibitor.exhibitor_kit if exhibitor&.exhibitor_kit.present?

            ensure_zone_capacity!(booth_price: booth_price)

            return exhibitor.create_exhibitor_kit!(build_exhibitor_kit_attributes(booth_price)) if exhibitor.present?

            exhibitor = Exhibitor.new(event: event, vendor: user)
            exhibitor.build_exhibitor_kit(build_exhibitor_kit_attributes(booth_price))
            exhibitor.save!
            exhibitor.exhibitor_kit
          end
        end
      end

      def find_or_create_vendor_user!
        email = registration_params[:pic_email_address].to_s.strip.downcase

        user = User.find_or_initialize_by(email: email)

        if user.persisted?
          user.assign_attributes(
            full_name: registration_params[:pic_full_name],
            phone: registration_params[:pic_contact_number],
            role: :vendor,
            email_verified_at: user.email_verified_at || Time.current
          )
          user.save! if user.changed?
          return user
        end

        password = 'TempPass123!'

        user.assign_attributes(
          full_name: registration_params[:pic_full_name],
          phone: registration_params[:pic_contact_number],
          role: :vendor,
          password: password,
          password_confirmation: password,
          email_verified_at: Time.current
        )
        user.save!
        user
      end

      def booth_quantity
        qty = params[:booth_quantity].to_i
        qty > 0 ? qty : 1
      end

      def build_exhibitor_kit_attributes(booth_price)
        custom_fields_data = (registration_params[:custom_fields_data] || {}).to_h
        payment_option = registration_params[:payment_option].to_s == 'later' ? 'later' : 'now'
        zone = booth_price.zone
        qty = booth_quantity

        {
          booth_number: registration_params[:booth_number],
          company_name: registration_params[:company_name],
          company_address: registration_params[:company_address],
          name_on_fascia: registration_params[:name_on_fascia],
          pic_full_name: registration_params[:pic_full_name],
          pic_position: registration_params[:pic_position],
          pic_contact_number: registration_params[:pic_contact_number],
          pic_email_address: registration_params[:pic_email_address],
          country: registration_params[:country],
          custom_fields_data: custom_fields_data.merge(payment_option: payment_option, zone: zone,
                                                       product_category: registration_params[:product_category]),
          exhibitor_booth_price: booth_price,
          booth_type: booth_price.booth_type,
          booth_quantity: qty,
          amount_paid: booth_price.price * qty,
          payment_status: :unpaid
        }
      end

      def registration_params
        params.permit(
          :company_name,
          :company_address,
          :booth_number,
          :name_on_fascia,
          :pic_full_name,
          :pic_position,
          :pic_contact_number,
          :pic_email_address,
          :country,
          :product_category,
          :payment_option,
          :exhibitor_booth_price_id,
          :booth_quantity,
          custom_fields_data: {}
        )
      end

      def upsert_vendor_profile!(user)
        profile = user.vendor_profile || user.reload.vendor_profile || user.build_vendor_profile

        profile.assign_attributes(
          category: registration_params[:product_category],
          person_in_charge: registration_params[:pic_full_name],
          address: registration_params[:company_address]
        )

        profile.save! if profile.new_record? || profile.changed?
      end

      def serialize_exhibitor_kit(exhibitor_kit)
        {
          id: exhibitor_kit.id,
          booth_number: exhibitor_kit.booth_number,
          company_name: exhibitor_kit.company_name,
          name_on_fascia: exhibitor_kit.name_on_fascia,
          pic_full_name: exhibitor_kit.pic_full_name,
          pic_position: exhibitor_kit.pic_position,
          pic_email_address: exhibitor_kit.pic_email_address,
          country: exhibitor_kit.country,
          booth_type: exhibitor_kit.booth_type,
          booth_quantity: exhibitor_kit.booth_quantity,
          amount_paid: exhibitor_kit.amount_paid,
          payment_status: exhibitor_kit.payment_status,
          payment_option: exhibitor_kit.custom_fields_data&.dig('payment_option') || 'now',
          payment_proof_uploaded: exhibitor_kit.payment_proof.attached?,
          payment_proof_url: exhibitor_kit.payment_proof.attached? ? url_for(exhibitor_kit.payment_proof) : nil,
          exhibitor_booth_price_id: exhibitor_kit.exhibitor_booth_price_id,
          custom_fields_data: exhibitor_kit.custom_fields_data || {}
        }
      end

      def serialize_registration_status(exhibitor_kit)
        if exhibitor_kit.blank?
          return {
            has_registered: false,
            exhibitor_kit_id: nil,
            exhibitor_booth_price_id: nil,
            booth_number: nil,
            booth_quantity: nil,
            payment_status: nil,
            company_name: nil,
            name_on_fascia: nil,
            pic_email_address: nil,
            pic_full_name: nil,
            pic_position: nil,
            pic_contact_number: nil,
            country: nil,
            preferred_booth_location: nil,
            other_services: [],
            booth_label: nil,
            price: nil,
            zone: nil,
            payment_proof_uploaded: false,
            payment_proof_url: nil
          }
        end

        {
          has_registered: true,
          exhibitor_kit_id: exhibitor_kit.id,
          exhibitor_booth_price_id: exhibitor_kit.exhibitor_booth_price_id,
          booth_number: exhibitor_kit.booth_number,
          booth_quantity: exhibitor_kit.booth_quantity,
          payment_status: exhibitor_kit.payment_status,
          company_name: exhibitor_kit.company_name,
          company_address: exhibitor_kit.company_address,
          name_on_fascia: exhibitor_kit.name_on_fascia,
          pic_email_address: exhibitor_kit.pic_email_address,
          pic_full_name: exhibitor_kit.pic_full_name,
          pic_position: exhibitor_kit.pic_position,
          pic_contact_number: exhibitor_kit.pic_contact_number,
          country: exhibitor_kit.country,
          product_category: exhibitor_kit.custom_fields_data&.dig('product_category') || exhibitor_kit.event_vendor&.vendor&.vendor_profile&.category,
          preferred_booth_location: exhibitor_kit.custom_fields_data&.dig('preferred_booth_location'),
          other_services: exhibitor_kit.custom_fields_data&.dig('other_services') || [],
          booth_label: exhibitor_kit.exhibitor_booth_price&.label,
          price: exhibitor_kit.amount_paid,
          zone: exhibitor_kit.custom_fields_data&.dig('zone') || exhibitor_kit.exhibitor_booth_price&.zone,
          payment_proof_uploaded: exhibitor_kit.payment_proof.attached?,
          payment_proof_url: exhibitor_kit.payment_proof.attached? ? url_for(exhibitor_kit.payment_proof) : nil,
          custom_fields_data: exhibitor_kit.custom_fields_data || {}
        }
      end

      def serialize_existing_registration(exhibitor_kit)
        {
          already_registered: true,
          exhibitor_kit_id: exhibitor_kit.id,
          price: exhibitor_kit.amount_paid,
          payment_option: exhibitor_kit.custom_fields_data&.dig('payment_option') || 'now',
          payment_required: exhibitor_kit.payment_status != 'paid',
          exhibitor_kit: serialize_exhibitor_kit(exhibitor_kit)
        }
      end

      def find_existing_registration(event:, email:)
        event.exhibitors
             .joins(:exhibitor_kit, :vendor)
             .where('LOWER(exhibitor_kits.pic_email_address) = :email OR LOWER(users.email) = :email', email: email)
             .includes(exhibitor_kit: :exhibitor_booth_price)
             .map(&:exhibitor_kit)
             .compact
             .max_by(&:created_at)
      end

      def ensure_zone_capacity!(booth_price:)
        qty = booth_quantity

        zone = booth_price.exhibitor_zone
        if zone.present?
          sold_count = zone_sold_count(zone_id: zone.id, event_id: booth_price.event_id)
          raise ZoneSoldOutError if zone.quota.present? && sold_count + qty > zone.quota
        end

        sold_count = booth_price_sold_count(booth_price_id: booth_price.id, event_id: booth_price.event_id)
        raise BoothPriceSoldOutError if booth_price.quota.present? && sold_count + qty > booth_price.quota
      end

      def exhibitor_sales_scope
        ExhibitorKit
          .joins(:event_vendor, :exhibitor_booth_price)
          .where(event_vendors: { type: 'Exhibitor' })
      end

      def zone_sold_counts(event)
        exhibitor_sales_scope
          .where(event_vendors: { event_id: event.id })
          .group('exhibitor_booth_prices.exhibitor_zone_id')
          .sum(:booth_quantity)
      end

      def zone_sold_count(zone_id:, event_id:)
        exhibitor_sales_scope
          .where(event_vendors: { event_id: event_id })
          .where(exhibitor_booth_prices: { exhibitor_zone_id: zone_id })
          .sum(:booth_quantity)
      end

      def booth_price_sold_counts(event)
        exhibitor_sales_scope
          .where(event_vendors: { event_id: event.id })
          .group('exhibitor_kits.exhibitor_booth_price_id')
          .sum(:booth_quantity)
      end

      def booth_price_sold_count(booth_price_id:, event_id:)
        exhibitor_sales_scope
          .where(event_vendors: { event_id: event_id })
          .where(exhibitor_kits: { exhibitor_booth_price_id: booth_price_id })
          .sum(:booth_quantity)
      end

      def manual_payment_zone?(zone)
        zone_value = zone.to_s.downcase.gsub(/[^a-z0-9]/, '')
        %w[zonea zoneb zonec].include?(zone_value)
      end

      def allowed_payment_proof_type?(payment_proof)
        payment_proof.content_type.in?(%w[image/jpeg image/png image/gif image/webp application/pdf])
      end

      def find_exhibitor_kit_for_event!(event:, exhibitor_kit_id:)
        ExhibitorKit
          .joins(:event_vendor)
          .where(id: exhibitor_kit_id, event_vendors: { event_id: event.id, type: 'Exhibitor' })
          .first!
      end

      def registration_email_matches?(exhibitor_kit:, email:)
        normalized_email = email.to_s.strip.downcase
        return false if normalized_email.blank?

        kit_email = exhibitor_kit.pic_email_address.to_s.strip.downcase
        vendor_email = exhibitor_kit.event_vendor&.vendor&.email.to_s.strip.downcase

        normalized_email == kit_email || normalized_email == vendor_email
      end
    end
  end
end
