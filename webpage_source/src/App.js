import { useState } from 'react';

import url_data from './data';

import './App.css';
import 'react-toastify/dist/ReactToastify.css';

import r_lang from './assets/r_lang.png';
import logo from './assets/logo.png';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import { faArrowCircleRight } from '@fortawesome/free-solid-svg-icons';
import { ToastContainer, toast } from 'react-toastify';



import Modal from 'react-modal';

const Section = ({url, name, func}) => {
  return (
    <div href={url} onClick={() => func()}>
      <section className="section">
        <img src={r_lang} className="r_langlogo" alt=" programming languague logo's" />
        <h3>{name}</h3>
        <div className="back_button">
          <FontAwesomeIcon className="backlogo" icon={faArrowCircleRight} />
        </div>
      </section>
    </div>
  )
}

const ModalTag = ({isModalOpen,setIsModalOpen,sendRequest}) => {

  const customStyles = {
    content: {
      top: '50%',
      left: '50%',
      right: 'auto',
      bottom: 'auto',
      marginRight: '-50%',
      transform: 'translate(-50%, -50%)',
    },
  };
  return (
    <Modal
      isOpen={isModalOpen}
      onRequestClose={() => setIsModalOpen(false)}
      contentLabel="Example Modal"
      style={customStyles}
      ariaHideApp={false}>
      <form id="modal-email" onSubmit={sendRequest}>
        <h2>Digite su correo electronico</h2>
        <input name="email" type="email" required />
        <button onSubmit={()=>console.log("Ay que rico")}>Ir al Markdown</button>
      </form>
    </Modal>
  )
}

//        
const App = () => {

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedMarkdown,setSelectedMarkdown] = useState()

  const sendRequest = (e) => {
    e.preventDefault();
    const email = e.target[0].value;
    toast.success("Correo guardado correctamente");
    console.log(selectedMarkdown)
    window.location.href = window.location.href+selectedMarkdown["url"]+`?email=${email}`
  }

  return (
    <>
    <ToastContainer/>
    <div>
      
      {isModalOpen && 
        <ModalTag 
        isModalOpen={isModalOpen}
        setIsModalOpen={setIsModalOpen}
        sendRequest={sendRequest}/>
      }
      <div id="title">
        <figure>
          <img src={logo} id="title_img" alt="Informatica Educativa Logo" />
        </figure>
        Markdowns
      </div>


      <div id="content">
        {url_data.map((e) => (
          <Section
            url={e.url}
            name={e.name}
            func={() => {
              setSelectedMarkdown(e)
              setIsModalOpen(true)
            }}
            key={e.url}
            
            />
        ))
        }
      </div>
    </div>
    </>
  )
}

export default App;
