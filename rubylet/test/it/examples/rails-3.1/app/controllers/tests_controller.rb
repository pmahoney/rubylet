class TestsController < ApplicationController
  def index
  end

  def log
    logger.info 'log action requested'
  end

  def large
    size = params[:size].to_i

    respond_to do |format|
      format.text { render :text => 'a' * size }
    end
  end
end
