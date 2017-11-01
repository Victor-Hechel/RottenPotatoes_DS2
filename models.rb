require 'data_mapper'
require "dm-migrations"


#SET DATESTYLE TO PostgreSQL,European;

DataMapper.setup(:default, "postgres://postgres:postgres@localhost/rotten")


class Comentario

	include DataMapper::Resource
	property :id, Serial
	property :comentario, String, :required => true

	belongs_to :usuario
	belongs_to :resenha
end

class Admin

	include DataMapper::Resource
	property :id, Serial
	property :nome, String, :required => true
	property :login, String, :required => true
	property :senha, String, :required => true


	def logar
		if (admin = getContaByLogin) != nil
			if senhaEstaCorreta(admin)
				return true;	
			end
		end
		return false
	end

	def getContaByLogin
		return Admin.first(:login => self.login)
	end
	def senhaEstaCorreta(admin)
		if admin.senha == self.senha
			return true
		end
		return false
	end
end

class Usuario

	include DataMapper::Resource
	property :id, Serial
	property :nome, String, :required => true
	property :dataDeNascimento, Date, :required => true
	property :email, String, :required => true
	property :critico, Boolean, :required => true
	property :login, String, :required => true
	property :senha, String, :required => true

	has n, :resenhas, :constraint => :destroy
	has n, :comentarios, :constraint => :destroy

	def logar
		if (usuario = getContaByLogin) != nil
			if senhaEstaCorreta(usuario)
				return true;	
			end
		end
		return false
	end

	def getContaByLogin
		user = Usuario.first(:login => self.login)
	end

	def emailEstaEmUso
		if(Usuario.first(:email => self.email) != nil)
			return true
		end
		return false
	end

	def senhaEstaCorreta(usuario)
		if usuario.senha == self.senha
			return true
		end
		return false
	end

	def senhaIgual(senha)
		if(self.senha == senha)
			return true
		else
			return false
		end
	end

	def verificaData
		if self.dataDeNascimento > Date.today
			return false
		end
		return true
	end
end


class Resenha

	include DataMapper::Resource
	property :id, Serial
	property :resenha, String, :required => false
	property :nota, Float, :required => true

	belongs_to :usuario
	belongs_to :show

	has n, :comentarios, :constraint => :destroy
end

class Show

	include DataMapper::Resource
	property :id, Serial
	property :titulo, String, :required => true
	property :diretor, String, :required => true
	property :genero, Enum[:Terror, :Acao, :Comedia, :Drama, :Animacao, :Romance], :required => true
	property :notaPublico, Float, :default => 0
	property :notaCriticos, Float, :default => 0
	property :sinopse, String, :required => true, :length => 250
	property :type, Discriminator

	has n, :resenhas, :constraint => :destroy
end

class Serie < Show
	property :numeroEpisodios, Integer
	property :numeroTemporadas, Integer
	property :dataInicio, Date
	property :dataFim, Date, :required => false
end

class Filme < Show
	property :dataLancamento, Date
end

DataMapper.finalize

DataMapper.auto_migrate!
DataMapper.auto_upgrade!

admin = Admin.new
admin.nome = "Victor"
admin.login = "admin"
admin.senha = Digest::MD5.hexdigest("12345")
admin.save
