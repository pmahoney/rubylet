class TestsController < ApplicationController
  def index
  end

  def log
    logger.info 'log action requested'
  end
end
