require 'spec_helper'

describe JobsController do

  describe "GET index" do
    before do
      async_handler_yaml =
        "--- !ruby/object:ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper\njob_data:\n  job_class: AgentCheckJob\n  job_id: 123id\n  queue_name: default\n  arguments:\n  - %d\n"

      Delayed::Job.create!(handler: async_handler_yaml % [agents(:jane_website_agent).id])
      Delayed::Job.create!(handler: async_handler_yaml % [agents(:bob_website_agent).id])
      Delayed::Job.create!(handler: async_handler_yaml % [agents(:jane_weather_agent).id])
      agents(:jane_website_agent).destroy
      Delayed::Job.create!(handler: async_handler_yaml % [agents(:bob_weather_agent).id], locked_at: Time.now, locked_by: 'test')

      expect(Delayed::Job.count).to be > 0
    end

    it "does not allow normal users" do
      expect(users(:bob)).not_to be_admin
      sign_in users(:bob)
      expect(get(:index)).to redirect_to(root_path)
    end

    it "returns all jobs" do
      expect(users(:jane)).to be_admin
      sign_in users(:jane)
      get :index
      expect(assigns(:jobs).length).to eq(4)
    end
  end

  describe "DELETE destroy" do
    before do
      @not_running = Delayed::Job.create
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      sign_in users(:jane)
    end

    it "destroy a job which is not running" do
      expect { delete :destroy, id: @not_running.id }.to change(Delayed::Job, :count).by(-1)
    end

    it "does not destroy a running job" do
      expect { delete :destroy, id: @running.id }.to change(Delayed::Job, :count).by(0)
    end
  end

  describe "PUT run" do
    before do
      @not_running = Delayed::Job.create(run_at: Time.now - 1.hour)
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      @failed = Delayed::Job.create(run_at: Time.now - 1.hour, locked_at: Time.now, failed_at: Time.now)
      sign_in users(:jane)
    end

    it "queue a job which is not running" do
      expect { put :run, id: @not_running.id }.to change { @not_running.reload.run_at }
    end

    it "queue a job that failed" do
      expect { put :run, id: @failed.id }.to change { @failed.reload.run_at }
    end

    it "not queue a running job" do
      expect { put :run, id: @running.id }.not_to change { @not_running.reload.run_at }
    end
  end

  describe "DELETE destroy_failed" do
    before do
      @failed = Delayed::Job.create(failed_at: Time.now - 1.minute)
      @running = Delayed::Job.create(locked_at: Time.now, locked_by: 'test')
      sign_in users(:jane)
    end

    it "just destroy failed jobs" do
      expect { delete :destroy_failed, id: @failed.id }.to change(Delayed::Job, :count).by(-1)
      expect { delete :destroy_failed, id: @running.id }.to change(Delayed::Job, :count).by(0)
    end
  end
end