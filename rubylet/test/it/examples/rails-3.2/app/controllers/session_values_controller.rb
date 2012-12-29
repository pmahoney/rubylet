require 'pp'

class SessionValuesController < ApplicationController
  def show
    key = params[:id]
    @session_value = session[key]
    @session_value = PP.pp(session.to_hash, '')
    logger.info @session_value
  end

  def update
    key = params[:id]
    val = params[:value]
    if key && val
      session[key] = val
      @session_value = PP.pp(session.to_hash, '')
      logger.info @session_value
    end
  end
end
