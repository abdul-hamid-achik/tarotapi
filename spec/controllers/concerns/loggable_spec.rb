require 'rails_helper'

# Create a test controller to test the concern
class TestLoggableController < ApplicationController
  include Loggable

  def log_something
    log_info("Info message", { extra: "info" })
    log_debug("Debug message", { extra: "debug" })
    log_warn("Warning message", { extra: "warn" })
    log_error("Error message", { extra: "error" })

    # Test tarot-themed logging methods
    divine("Divine message", { extra: "divine" })
    reveal("Reveal message", { extra: "reveal" })
    obscure("Obscure message", { extra: "obscure" })
    prophecy("Prophecy message", { extra: "prophecy" })
    meditate("Meditate message", { extra: "meditate" })

    # Test operations with block
    result = with_logging("operation") { "operation result" }
    divine_ritual("ritual") { "ritual result" }

    render json: { status: "logged" }
  end
end

# Configure routes for testing
RSpec.describe Loggable, type: :controller do
  controller(TestLoggableController) do
  end

  describe "logging methods" do
    before do
      # Set up routes for testing
      routes.draw { get 'log_something' => 'test_loggable#log_something' }

      # Stub all TarotLogger methods to prevent actual logging
      allow(TarotLogger).to receive(:info).and_return(nil)
      allow(TarotLogger).to receive(:debug).and_return(nil)
      allow(TarotLogger).to receive(:warn).and_return(nil)
      allow(TarotLogger).to receive(:error).and_return(nil)
      allow(TarotLogger).to receive(:divine).and_return(nil)
      allow(TarotLogger).to receive(:reveal).and_return(nil)
      allow(TarotLogger).to receive(:obscure).and_return(nil)
      allow(TarotLogger).to receive(:prophecy).and_return(nil)
      allow(TarotLogger).to receive(:meditate).and_return(nil)
      allow(TarotLogger).to receive(:with_task).and_yield
      allow(TarotLogger).to receive(:divine_ritual).and_yield
    end

    it "calls the standard logging methods with context" do
      expect(TarotLogger).to receive(:info).with("Info message", hash_including(class_name: "TestLoggableController", extra: "info"))
      expect(TarotLogger).to receive(:debug).with("Debug message", hash_including(class_name: "TestLoggableController", extra: "debug"))
      expect(TarotLogger).to receive(:warn).with("Warning message", hash_including(class_name: "TestLoggableController", extra: "warn"))
      expect(TarotLogger).to receive(:error).with("Error message", hash_including(class_name: "TestLoggableController", extra: "error"))

      get :log_something
    end

    it "calls the tarot-themed logging methods with context" do
      expect(TarotLogger).to receive(:divine).with("Divine message", hash_including(class_name: "TestLoggableController", extra: "divine"))
      expect(TarotLogger).to receive(:reveal).with("Reveal message", hash_including(class_name: "TestLoggableController", extra: "reveal"))
      expect(TarotLogger).to receive(:obscure).with("Obscure message", hash_including(class_name: "TestLoggableController", extra: "obscure"))
      expect(TarotLogger).to receive(:prophecy).with("Prophecy message", hash_including(class_name: "TestLoggableController", extra: "prophecy"))
      expect(TarotLogger).to receive(:meditate).with("Meditate message", hash_including(class_name: "TestLoggableController", extra: "meditate"))

      get :log_something
    end

    it "calls the block-based logging methods with context" do
      expect(TarotLogger).to receive(:with_task).with("operation", hash_including(class_name: "TestLoggableController"))
      expect(TarotLogger).to receive(:divine_ritual).with("ritual", hash_including(class_name: "TestLoggableController"))

      get :log_something
    end

    it "includes controller-specific context in log_context" do
      controller_instance = controller

      # Simulate a request to ensure request object is available
      get :log_something

      # Now check the controller's log_context method
      context = controller_instance.send(:log_context)

      expect(context).to include(:class_name)
      expect(context[:class_name]).to eq("TestLoggableController")
    end
  end

  describe "class methods" do
    it "provides logging methods at the class level" do
      expect(TarotLogger).to receive(:info).with("Class info", hash_including(class_name: "TestLoggableController"))
      expect(TarotLogger).to receive(:debug).with("Class debug", hash_including(class_name: "TestLoggableController"))
      expect(TarotLogger).to receive(:warn).with("Class warn", hash_including(class_name: "TestLoggableController"))
      expect(TarotLogger).to receive(:error).with("Class error", hash_including(class_name: "TestLoggableController"))

      TestLoggableController.log_info("Class info")
      TestLoggableController.log_debug("Class debug")
      TestLoggableController.log_warn("Class warn")
      TestLoggableController.log_error("Class error")
    end

    it "provides tarot-themed logging methods at the class level" do
      expect(TarotLogger).to receive(:divine).with("Class divine", hash_including(class_name: "TestLoggableController"))
      expect(TarotLogger).to receive(:reveal).with("Class reveal", hash_including(class_name: "TestLoggableController"))
      expect(TarotLogger).to receive(:obscure).with("Class obscure", hash_including(class_name: "TestLoggableController"))
      expect(TarotLogger).to receive(:prophecy).with("Class prophecy", hash_including(class_name: "TestLoggableController"))

      TestLoggableController.divine("Class divine")
      TestLoggableController.reveal("Class reveal")
      TestLoggableController.obscure("Class obscure")
      TestLoggableController.prophecy("Class prophecy")
    end
  end
end
