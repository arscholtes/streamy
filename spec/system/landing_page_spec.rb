require 'rails_helper'

RSpec.describe "Landing Page", type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  describe "Hero Section" do
    it "displays the main heading with correct text" do
      visit pages_landing_path

      within "#hero" do
        expect(page).to have_selector("h1", text: "Building strong brands through technology")
      end
    end

    it "displays a CTA button" do
      visit pages_landing_path

      within "#hero" do
        expect(page).to have_button("Get Started")
      end
    end

    it "has dark background color" do
      visit pages_landing_path

      hero_section = page.find("#hero")

      # Check computed style for background
      background = page.evaluate_script("window.getComputedStyle(document.querySelector('#hero')).background")

      expect(background).to include("gradient").or include("rgb")
    end

    it "has fade-in animation on page load" do
      visit pages_landing_path

      hero_section = page.find("#hero")

      # Check if element has fade-in data attribute
      expect(hero_section["data-controller"]).to include("fade-in")

      # Check if opacity transitions from 0 to 1 (visible)
      final_opacity = page.evaluate_script("window.getComputedStyle(document.querySelector('#hero')).opacity")
      expect(final_opacity.to_f).to be > 0.9
    end
  end

  describe "Features Section" do
    it "displays 4 feature cards" do
      visit pages_landing_path

      within "#features" do
        expect(page).to have_selector(".feature-card", count: 4)
      end
    end

    it "displays feature cards in a responsive grid layout" do
      visit pages_landing_path

      features_section = page.find("#features")
      display_value = page.evaluate_script("window.getComputedStyle(document.querySelector('#features .features-grid')).display")

      expect(display_value).to eq("grid")
    end

    it "each feature card has an icon, title, and description" do
      visit pages_landing_path

      within "#features" do
        feature_cards = page.all(".feature-card")

        expect(feature_cards.count).to eq(4)

        feature_cards.each do |card|
          expect(card).to have_selector(".feature-icon")
          expect(card).to have_selector(".feature-title")
          expect(card).to have_selector(".feature-description")
        end
      end
    end

    it "feature cards have hover animations with scale and glow effect" do
      visit pages_landing_path

      # Find first feature card
      first_card = page.find(".feature-card", match: :first)

      # Check that card has data-controller for feature-card
      expect(first_card["data-controller"]).to include("feature-card")

      # Hover over the card
      first_card.hover

      # Give a moment for transition to start
      sleep 0.1

      # Check that transform property is applied
      transform = page.evaluate_script("window.getComputedStyle(document.querySelector('.feature-card')).transform")
      expect(transform).not_to eq("none")
    end
  end

  describe "Testimonials Carousel" do
    it "displays at least 3 testimonial cards" do
      visit pages_landing_path

      within "#testimonials" do
        expect(page).to have_selector(".testimonial-card", minimum: 3, visible: :all)
      end
    end

    it "has navigation buttons for previous and next" do
      visit pages_landing_path

      within "#testimonials" do
        expect(page).to have_button(class: "carousel-btn-prev")
        expect(page).to have_button(class: "carousel-btn-next")
      end
    end

    it "navigates to next testimonial when next button is clicked" do
      visit pages_landing_path

      within "#testimonials" do
        # Get initial active card index
        initial_active = page.find(".testimonial-card.active")
        initial_text = initial_active.text

        # Click next button
        find(".carousel-btn-next").click

        sleep 0.3 # Wait for transition

        # Get new active card
        new_active = page.find(".testimonial-card.active")
        new_text = new_active.text

        # Should be different
        expect(new_text).not_to eq(initial_text)
      end
    end

    it "has carousel controller for auto-scroll functionality" do
      visit pages_landing_path

      carousel = page.find("#testimonials")
      expect(carousel["data-controller"]).to include("carousel")
    end
  end
end
