# frozen_string_literal: true

class CounterpartyInboundSummariesController < ApplicationController
  before_action :require_admin

  def index
    render json: { summaries: CounterpartyInboundSummary.call }
  end
end