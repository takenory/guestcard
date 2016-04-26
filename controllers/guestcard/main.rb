require 'al_template'

class AlController
  def action_create
    @part_template = "guestcard/_create.html"
    AlTemplate.run("layouts/application.html")
  end

  def action_create_submit
    @part_template = "guestcard/_create_submit.html"
    AlTemplate.run("layouts/application.html")
  end
end
