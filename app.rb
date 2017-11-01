require 'sinatra'
require 'erb'
require 'sinatra/flash'
require 'date'
require 'json'

require_relative 'models.rb'

enable :sessions

before '/admin/*' do
	if(session[:admin] != "t")
		flash[:mensagem] = "Você não tem permissão"
		if session[:id] == nil
			redirect '/'
		else
			redirect '/logged/menu'
		end
	end
end

before '/logged/*' do
	if session[:id] == nil
		flash[:mensagem] = "Você deve logar para acessar a página"
		redirect '/'
	end
end

before '/loggedOnly/*' do
	if session[:id] == nil || session[:admin] == "t"
		flash[:mensagem] = "Você não tem permissão"
		if session[:id] == nil
			redirect '/'
		else
			redirect '/logged/menu'
		end
	end
end

get '/' do
	erb :index, :layout => nil
end

post '/logar' do
	login = params["login"].to_s
	senha = Digest::MD5.hexdigest(params["senha"].to_s)

	usuario = Usuario.new
	usuario.login = login
	usuario.senha = senha

	if usuario.logar
		usuario = usuario.getContaByLogin
		session[:id] = usuario.id
		session[:login] = usuario.login
		session[:admin] = "f"
		session[:critico] = usuario.critico.to_s
		redirect "/logged/listar/filmes"
	else
		admin = Admin.new
		admin.login = login
		admin.senha = senha

		if admin.logar
			session[:id] = admin.getContaByLogin.id
			session[:login] = admin.login
			session[:admin] = "t"
			redirect "/logged/listar/filmes"
		else
			flash[:mensagem] = "Login ou senha estão incorretos"
			redirect "/"
		end
	end
end

get '/criarConta' do
	erb :criarConta, :layout => nil
end

post '/criarConta' do
	usuario = Usuario.new
	usuario.login = params["login"]
	usuario.email = params["email"]
	usuario.senha = params["senha"]
	usuario.dataDeNascimento = Date.parse params["dataDeNascimento"].to_s

	if usuario.getContaByLogin == nil
		if !usuario.emailEstaEmUso 
			if usuario.senhaIgual(params["senha2"].to_s)
				if usuario.verificaData
					usuario.nome = params["nome"]
					usuario.dataDeNascimento = params["dataDeNascimento"]
					usuario.critico = false
					usuario.senha = Digest::MD5.hexdigest(usuario.senha)

					if !usuario.save
						flash[:mensagem] = "Ocorreu algum erro, tente novamente"
						redirect '/criarConta'
					end

					if usuario.logar
						session[:id] = usuario.id
						session[:login] = usuario.login
						session[:critico] = usuario.critico.to_s
						session[:admin] = "f"
					end

					redirect "/logged/listar/filmes"
				else
					flash[:mensagem] = "Data inválida"
				end
			else
				flash[:mensagem] = "Senhas devem ser iguais"
			end
		else
			flash[:mensagem] = "Email já está em uso"
		end
	else
		flash[:mensagem] = "Login já está em uso"
	end
	redirect '/criarConta'
end

get '/logged/menu' do
	erb :menu
end

get '/admin/cadastrarShow' do
	erb :cadastrarShow
end

post '/admin/cadastrarShow' do

	id = nil

	if(fileIsNotNull(params["cartaz"]))
		if(isjpg(params["cartaz"]))
			if params["tipo"] == "filme"
				filme = Filme.new
				filme.titulo = params["titulo"]
				filme.diretor = params["diretor"]
				filme.genero = params["genero"]
				filme.sinopse = params["sinopse"]
				filme.dataLancamento = Date.parse params["dataLancamento"].to_s
				filme.save
				id = filme.id
			elsif params["tipo"] == "serie"
				serie = Serie.new
				serie.titulo = params["titulo"]
				serie.diretor = params["diretor"]
				serie.genero = params["genero"]
				serie.sinopse = params["sinopse"]
				serie.numeroEpisodios = params["numeroEpisodios"]
				serie.numeroTemporadas = params["numeroTemporadas"]
				serie.dataInicio = Date.parse params["dataInicio"].to_s
				if(params["dataFim"] == "")
					serie.dataFim = nil
				else
					serie.dataFim = Date.parse params["dataFim"].to_s
				end

				serie.save
				id = serie.id
			end

			File.open('./public/uploads/shows/' + id.to_s + ".jpg", "w") do |f|
				f.write(params['cartaz'][:tempfile].read)
			end

			flash[:mensagem] = "Show cadastrado com sucesso"
			if(params["tipo"] == "filme")
				redirect '/logged/listar/filmes'
			else
				redirect '/logged/listar/series'
			end	
			
		else
			flash[:mensagem] = "Cartaz deve estar em jpg"
			redirect '/admin/cadastrarShow'
		end
	else
		flash[:mensagem] = "Você deve cadastrar cartaz"
		redirect '/admin/cadastrarShow'
	end

end

get '/admin/cadastrarCritico' do
	erb :cadastrarCritico
end

post '/admin/cadastrarCritico' do
	usuario = Usuario.new
	usuario.login = params["login"]
	usuario.email = params["email"]

	if usuario.getContaByLogin == nil && !usuario.emailEstaEmUso
		usuario.nome = params["nome"]
		usuario.dataDeNascimento = params["dataDeNascimento"]
		usuario.critico = true
		usuario.senha = Digest::MD5.hexdigest(params["senha"])

		usuario.save

		usuario.logar

		redirect "/logged/menu"
	else
		flash[:mensagem] = "Login ou email já estão em uso"
		redirect "/admin/cadastrarCritico"
	end
end

get '/logged/listar/:tipo' do
	@tipo = params["tipo"].downcase
	if @tipo == "series"
		@tipo = "Séries"
		@shows = Serie.all
	elsif @tipo == "filmes"
		@tipo = "Filmes"
		@shows = Filme.all
	end
	erb :listarShows
end

get '/logged/showDetalhes/:tipo/:id' do
	@detalhe = params["tipo"].downcase
	if @detalhe == "filmes"
		@show = Filme.get(params["id"].to_i)
	elsif @detalhe == "series"
		@show = Serie.get(params["id"].to_i)
	end
	erb :showDetalhes
end


get '/admin/excluirShow/:tipo/:id' do
	show = Show.get(params["id"]);
	File.delete("./public/uploads/shows/" + show.id.to_s + ".jpg")
	show.destroy
	flash[:mensagem] = "Show excluído com sucesso"
	redirect '/logged/listar/'+params["tipo"]
end

get '/admin/editarShow/:tipo/:id' do
	@tipo = params["tipo"].downcase
	if @tipo == "series"
		@show = Serie.get(params["id"])
	elsif @tipo == "filmes"
		@show = Filme.get(params["id"])
	end
	erb :editarShow
end

post '/admin/editarShow' do
	tipo = params["tipo"]
	isjpg = false
	
	isNotNull = fileIsNotNull(params["cartaz"])
	if isNotNull
		if !isjpg(params["cartaz"])
			flash[:mensagem] = "Cartaz deve ser jpg"
			redirect '/admin/editarShow/' + tipo + '/' + params["id"]
			return nil 
		end			
	end	
	
	if tipo == "series"
		dataFim = params["dataFim"]
		if(dataFim == "")
			dataFim = nil
		end
		show = Serie.get(params["id"].to_i)
		show.update(:titulo => params["titulo"],
			        :diretor => params["diretor"],
			        :genero => params["genero"],
			        :sinopse => params["sinopse"],
			        :dataInicio => (Date.parse params["dataInicio"].to_s),
			        :dataFim => (Date.parse dataFim.to_s),
			        :numeroEpisodios => params["numeroEpisodios"].to_i,
			        :numeroTemporadas => params["numeroTemporadas"].to_i)
	elsif tipo == "filmes"
		show = Filme.get(params["id"].to_i)
		show.update(:titulo => params["titulo"],
			        :diretor => params["diretor"],
			        :genero => params["genero"],
			        :sinopse => params["sinopse"],
			        :dataLancamento => params["dataLancamento"])
	end

	if(isNotNull)
		File.delete("./public/uploads/shows/" + show.id.to_s + ".jpg")
		File.open('./public/uploads/shows/' + show.id.to_s + ".jpg", "w") do |f|
			f.write(params['cartaz'][:tempfile].read)
		end
	end
	

	flash[:mensagem] = "Show editado com sucesso"
	redirect '/logged/listar/' + tipo
end

get '/admin/listarUsuarios' do
	@usuarios = Usuario.all
	erb :listarUsuarios
end

get '/admin/excluirUsuario/:id' do
	usuario = Usuario.get(params["id"])
	shows = []
	isCritico = usuario.critico
	usuario.resenhas.each do |resenha|
		shows << resenha.show
	end
	Usuario.get(params["id"]).destroy
	shows.each do |show|
		reavaliarNotaShow(show.id, isCritico)
	end
	flash[:mensagem] = "Usuário excluído com sucesso";
	redirect '/admin/listarUsuarios'
end

get '/admin/mudaCritico/:id' do
	usuario = Usuario.get(params['id'])
	if(usuario.critico == true)
		usuario.update(:critico => false)
	else
		usuario.update(:critico => true)
	end



	usuario.resenhas.each do |resenha|
		reavaliarNotaShow(resenha.show.id, true)
		reavaliarNotaShow(resenha.show.id, false)
	end

	redirect '/admin/listarUsuarios'
end

get '/loggedOnly/adicionarResenha/:id' do
	@id = params["id"]
	erb :adicionarResenha
end

post '/loggedOnly/adicionarResenha' do
	resenha = Resenha.new
	resenha.resenha = params["resenha"]
	resenha.nota = params["nota"]

	show = Show.get(params["idShow"])
	usuario = Usuario.get(session[:id])

	resenha.show = show
	resenha.usuario = usuario

	resenha.save

	show.resenhas << resenha
	usuario.resenhas << resenha

	show.save
	usuario.save

	reavaliarNotaShow(show.id, usuario.critico)

	redirect '/logged/menu'
end

get '/logged/excluirResenha/:id' do
	resenha = Resenha.get(params["id"].to_i)
	idShow = resenha.show.id
	isCritico = resenha.usuario.critico
	Resenha.get(params["id"].to_i).destroy
	reavaliarNotaShow(idShow, isCritico)
	redirect '/logged/menu'
end

get '/loggedOnly/editarResenha/:id' do
	@resenha = Resenha.get(params["id"])

	erb :editarResenha
end


post '/loggedOnly/editarResenha' do
	resenha = Resenha.get(params["idResenha"])

	resenha.update(:resenha => params["resenha"], :nota => params["nota"])
	reavaliarNotaShow(resenha.show.id, resenha.usuario.critico)
	redirect '/logged/menu'
end

post '/loggedOnly/adicionarComentario' do
	comentario = Comentario.new
	comentario.comentario = params["comentario"]

	usuario = Usuario.get(session["id"])
	resenha = Resenha.get(params["id"])

	comentario.usuario = usuario
	comentario.resenha = resenha

	comentario.save

	usuario.comentarios << comentario
	resenha.comentarios << comentario

	usuario.save
	resenha.save
	redirect '/logged/menu'
end

get '/logged/excluirComentario/:id' do
	comentario = Comentario.get(params["id"])
	comentario.destroy

	redirect("/logged/menu")
end

get '/logged/getFilmesByTitulo/:titulo' do
	titulo = params[:titulo].upcase
	filmes = Filme.all(:titulo.like => "%"+titulo+"%")
	filmes.each do |filme|
		puts "------------------"
		puts filme.titulo
	end
	return filmes.to_json
end

get '/logged/pesquisaFilme' do
	titulo = params["pesquisa"];
	filme = Filme.first(:titulo => titulo)
	if(filme != nil)
		redirect '/logged/showDetalhes/filmes/'+filme.id.to_s
	else
		flash[:mensagem] = "Filme não encontrado"
		redirect '/logged/listar/filmes'
	end
end

get '/logged/usuarioDetalhes' do
	if session[:admin] == "t"
		@usuario = Admin.get(session[:id].to_i)
	else
		@usuario = Usuario.get(session[:id].to_i)
	end

	erb :usuarioDetalhes
end

get '/logged/editarUsuario' do
	if(session[:admin] == "t")
		@usuario = Admin.get(session[:id].to_i)
	else
		@usuario = Usuario.get(session[:id].to_i)
	end

	erb :editarUsuario
end

post '/logged/editarUsuario' do
	if session[:admin] == "t"
		usuario = Admin.get(session[:id].to_i)
		usuario.update(:nome => params["nome"],
			  		   :login => params["login"],
			  		   :senha => Digest::MD5.hexdigest(params["senha"].to_s))
	else
		usuario = Usuario.get(session[:id].to_i)
		usuario.update(:nome => params["nome"],
					   :login => params["login"],
					   :senha => Digest::MD5.hexdigest(params["senha"].to_s),
					   :email => params["email"],
					   :dataDeNascimento => params["dataDeNascimento"])
	end
	flash[:mensagem] = "Usuário editado com sucesso"
	redirect '/logged/usuarioDetalhes'
end

get '/logged/logout' do
	session.clear
	flash[:mensagem] = "Usuário deslogado"
	redirect '/'
end

def fileIsNotNull(req)
	if req != nil
		return true
	else
		return false
	end
end

def isjpg(req)
	extensao = File.extname(req[:filename])
	if(extensao == ".jpg")
		return true
	end
	return false
end

def reavaliarNotaShow(id, isCritico)
	show = Show.get(id)
	num_resenhas = 0;
	notaTotal = 0;
	show.resenhas.each do |resenha|
		if resenha.usuario.critico == isCritico
			notaTotal = notaTotal + resenha.nota
			num_resenhas = num_resenhas + 1
		end
	end

	if(num_resenhas != 0)
		notaTotal = notaTotal/num_resenhas
	else
		notaTotal = 0
	end

	if isCritico
		show.update(:notaCriticos => notaTotal)
	else
		show.update(:notaPublico => notaTotal)
	end
end