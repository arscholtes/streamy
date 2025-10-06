require 'rails_helper'

RSpec.describe StreamsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:live_stream) { create(:stream, user: user, status: 'live', title: 'Live Gaming Stream') }
  let!(:offline_stream) { create(:stream, user: other_user, status: 'offline') }

  describe 'GET /streams' do
    it 'shows live streams by default' do
      get streams_path

      expect(response).to have_http_status(:success)
      expect(assigns(:streams)).to include(live_stream)
      expect(assigns(:total_live)).to eq(1)
    end

    it 'filters by live streams' do
      get streams_path, params: { filter: 'live' }

      expect(assigns(:streams)).to include(live_stream)
      expect(assigns(:streams)).not_to include(offline_stream)
    end

    it 'shows all streams when filter is all' do
      get streams_path, params: { filter: 'all' }

      expect(assigns(:streams)).to include(live_stream)
      expect(assigns(:streams)).to include(offline_stream)
    end

    it 'searches streams by title' do
      get streams_path, params: { search: 'Gaming' }

      expect(assigns(:streams)).to include(live_stream)
    end

    it 'sorts by recent' do
      get streams_path, params: { sort: 'recent' }

      expect(response).to have_http_status(:success)
    end

    it 'sorts by popular' do
      get streams_path, params: { sort: 'popular' }

      expect(response).to have_http_status(:success)
    end

    it 'paginates results' do
      get streams_path, params: { page: 1 }

      expect(response).to have_http_status(:success)
    end

    it 'includes stream statistics' do
      get streams_path

      expect(assigns(:total_live)).to eq(Stream.live.count)
      expect(assigns(:total_streams)).to eq(Stream.count)
    end
  end

  describe 'GET /streams/:id' do
    let!(:chat_message) { create(:chat_message, stream: live_stream, user: user) }

    it 'shows stream page' do
      get stream_path(live_stream)

      expect(response).to have_http_status(:success)
      expect(assigns(:stream)).to eq(live_stream)
    end

    it 'loads related streams' do
      related_stream = create(:stream, status: 'live')

      get stream_path(live_stream)

      expect(assigns(:related_streams)).to include(related_stream)
      expect(assigns(:related_streams)).not_to include(live_stream)
    end

    it 'loads recent chat messages' do
      get stream_path(live_stream)

      expect(assigns(:chat_messages)).to include(chat_message)
    end

    it 'limits chat messages to last 100' do
      get stream_path(live_stream)

      expect(assigns(:chat_messages).count).to be <= 100
    end

    it 'handles non-existent stream' do
      get stream_path(id: 99999)

      expect(response).to redirect_to(streams_path)
      expect(flash[:alert]).to eq('Stream not found')
    end
  end

  describe 'GET /streams/:id/edit' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    end

    it 'shows edit page for stream owner' do
      get edit_stream_path(live_stream)

      expect(response).to have_http_status(:success)
      expect(assigns(:stream)).to eq(live_stream)
    end

    it 'redirects non-owner' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(other_user)

      get edit_stream_path(live_stream)

      expect(response).to redirect_to(streams_path)
      expect(flash[:alert]).to eq('You are not authorized to edit this stream')
    end

    it 'requires login' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false)

      get edit_stream_path(live_stream)

      expect(response).to redirect_to(login_path)
    end
  end

  describe 'PATCH /streams/:id' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    end

    it 'updates stream title' do
      patch stream_path(live_stream), params: {
        stream: { title: 'Updated Stream Title' }
      }

      expect(response).to redirect_to(stream_path(live_stream))
      expect(flash[:notice]).to eq('Stream updated successfully!')
      expect(live_stream.reload.title).to eq('Updated Stream Title')
    end

    it 're-renders edit on validation error' do
      patch stream_path(live_stream), params: {
        stream: { title: '' }
      }

      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end

    it 'prevents non-owner from updating' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(other_user)

      patch stream_path(live_stream), params: {
        stream: { title: 'Hacked Title' }
      }

      expect(response).to redirect_to(streams_path)
      expect(flash[:alert]).to eq('You are not authorized to edit this stream')
      expect(live_stream.reload.title).not_to eq('Hacked Title')
    end

    it 'requires login' do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(false)

      patch stream_path(live_stream), params: {
        stream: { title: 'New Title' }
      }

      expect(response).to redirect_to(login_path)
    end
  end
end
