RedmineApp::Application.routes.draw do

  # routes for issue attachments queries in the global menu
  resources :issue_attachment_queries, :except => [:show]

  # routes for issue attachment queries in the project menu
  resources :projects do
      resources :issue_attachment_queries, :only => [:new, :create]
  end
  
  # routes for the index view in the projects menu
  match "/projects/:id/issue_attachments" => "issue_attachments#index", :as => "project_issue_attachments", :via => [:get]

  # issue attachments routes all requests but 'index' to attachments
  resources :issue_attachments do 
    collection do
      post 'bulk_pdf'
      post 'bulk_zip'
    end
  end

  # routes for the issue attachments context menu
  match "/issue_attachments_menu" => "issue_attachments#issue_attachments_menu", :as => "issue_attachments_menu",     :via => [:get]

end
